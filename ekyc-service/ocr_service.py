import gc
import os
import re
import threading

import cv2
import numpy as np
import torch
import easyocr

# CRAFT cấp phát ~width*height*64*4 byte. 1120px giữ chữ CCCD/GPLX rõ
# mà nhanh hơn 1280 và tránh OOM trên máy ~8GB.
_MAX_OCR_SIDE = 1120

_reader = None
_reader_lock = threading.Lock()
# EasyOCR không an toàn khi chạy song song trên máy ít RAM: hai request cùng lúc
# nhân đôi vùng nhớ đỉnh và cùng chết. Xếp hàng để mỗi lần chỉ giữ một bản.
_ocr_lock = threading.Lock()


def get_reader():
    global _reader
    if _reader is None:
        with _reader_lock:
            if _reader is None:
                # 1 thread quá chậm; 4 thread trên máy 8GB dễ đỉnh RAM. 2 là cân bằng tốt.
                threads = max(1, min(2, os.cpu_count() or 2))
                torch.set_num_threads(threads)
                _reader = easyocr.Reader(['vi', 'en'], gpu=False, verbose=False)
    return _reader


def warmup() -> None:
    """Nạp model sẵn lúc start server để lần upload đầu không chờ 10–20s."""
    reader = get_reader()
    blank = np.full((160, 320, 3), 240, dtype=np.uint8)
    with _ocr_lock:
        with torch.no_grad():
            reader.readtext(
                blank,
                detail=0,
                paragraph=False,
                canvas_size=320,
                mag_ratio=1.0,
                min_size=20,
            )


def _resize_for_ocr(image_np: np.ndarray) -> np.ndarray:
    h, w = image_np.shape[:2]
    longest = max(h, w)
    if longest <= _MAX_OCR_SIDE:
        return image_np
    scale = _MAX_OCR_SIDE / float(longest)
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    return cv2.resize(image_np, (new_w, new_h), interpolation=cv2.INTER_AREA)


def _read_text(image_np: np.ndarray) -> str:
    with _ocr_lock:
        reader = get_reader()
        with torch.no_grad():
            raw = reader.readtext(
                image_np,
                detail=0,
                paragraph=False,          # gộp đoạn làm chậm, parser của ta dùng regex trên full text
                decoder='greedy',         # nhanh hơn beamsearch
                batch_size=1,
                canvas_size=_MAX_OCR_SIDE,
                mag_ratio=1.0,
                min_size=28,              # bỏ box nhiễu nhỏ → ít vòng nhận dạng hơn
                text_threshold=0.65,
                low_text=0.35,
                link_threshold=0.4,
            )
        return '\n'.join(raw)


def ocr_image(image_np: np.ndarray, expected_type: str | None = None) -> dict:
    """OCR theo loại giấy tờ mà client đang upload.

    expected_type:
      - cccd / cccd_front: bắt buộc số 12 số (mặt trước)
      - cccd_back: nới lỏng hơn (mặt sau)
      - license / license_front: hạng bằng / số GPLX + tên
      - license_back: chỉ cần đọc được chữ trên ảnh
      - None / auto: tự nhận diện (legacy)
    """
    try:
        text = _read_text(_resize_for_ocr(image_np))
    except (MemoryError, RuntimeError):
        gc.collect()
        return {
            'code': 422,
            'data': {},
            'raw_text': '',
            'message': 'Máy chủ nhận dạng đang thiếu bộ nhớ — vui lòng thử lại sau ít giây',
        }
    except Exception as e:
        gc.collect()
        return {
            'code': 422,
            'data': {},
            'raw_text': '',
            'message': f'Không đọc được ảnh giấy tờ — vui lòng thử lại ({type(e).__name__})',
        }

    if not text or len(text.strip()) < 8:
        return {
            'code': 422,
            'data': {},
            'raw_text': text or '',
            'message': 'Không đọc được chữ trên ảnh — chụp rõ, đủ sáng, không bị cắt',
        }

    hint = (expected_type or 'auto').strip().lower()
    detected = _detect_type(text)

    if hint in ('cccd', 'cccd_front', 'cccd_back'):
        doc_type = 'cccd'
        fields = _parse_cccd(text)
    elif hint in ('license', 'license_front', 'license_back'):
        doc_type = 'license'
        fields = _parse_license(text)
    else:
        doc_type = detected
        fields = _parse_license(text) if doc_type == 'license' else _parse_cccd(text)

    fields['doc_type'] = doc_type
    fields['detected_type'] = detected

    # Sai loại giấy tờ rõ ràng so với bước đang upload
    if hint in ('cccd', 'cccd_front') and detected == 'license':
        return {
            'code': 422,
            'data': fields,
            'raw_text': text,
            'message': 'Ảnh giống bằng lái xe — vui lòng upload mặt trước CCCD',
        }
    if hint in ('license', 'license_front') and detected == 'cccd':
        return {
            'code': 422,
            'data': fields,
            'raw_text': text,
            'message': 'Ảnh giống CCCD — vui lòng upload mặt trước bằng lái xe',
        }

    ok, reason = _is_valid_for_step(hint, doc_type, fields, text)
    if not ok:
        return {
            'code': 422,
            'data': fields,
            'raw_text': text,
            'message': reason,
        }

    return {
        'code': 200,
        'data': fields,
        'raw_text': text,
        'message': 'ok',
    }


def _is_valid_for_step(hint: str, doc_type: str, fields: dict, text: str) -> tuple[bool, str]:
    has_id = bool(fields.get('id')) and str(fields.get('id')).isdigit() and len(str(fields['id'])) == 12
    has_name = bool(fields.get('name')) and len(str(fields['name']).strip()) >= 3
    has_class = bool(fields.get('type'))
    upper = text.upper()

    if hint in ('license', 'license_front'):
        if has_class and (has_id or has_name):
            return True, 'ok'
        if has_id and has_name:
            return True, 'ok'
        if has_class:
            return True, 'ok'
        return False, 'Không nhận ra bằng lái — cần thấy hạng (A1/B1/B2…) hoặc số GPLX + họ tên'

    if hint == 'license_back':
        if len(text.strip()) >= 12:
            return True, 'ok'
        return False, 'Không nhận dạng được mặt sau bằng lái — chụp lại rõ hơn'

    if hint == 'cccd_back':
        looks_cccd = any(kw in upper for kw in _CCCD_KW) or has_id or has_name
        if looks_cccd or fields.get('expiry') or fields.get('home') or fields.get('issue_date'):
            return True, 'ok'
        if len(text.strip()) >= 20:
            return True, 'ok'
        return False, 'Không nhận dạng được mặt sau CCCD — chụp lại rõ hơn'

    if hint in ('cccd', 'cccd_front'):
        if has_id:
            return True, 'ok'
        return False, 'Không đọc được số CCCD 12 số — chụp rõ phần số căn cước'

    # auto / legacy
    if doc_type == 'license':
        if has_class and (has_id or has_name):
            return True, 'ok'
        if has_id and has_name:
            return True, 'ok'
        return False, 'Không nhận ra bằng lái — cần thấy hạng (A1/B1/B2…) hoặc số GPLX + họ tên'

    if has_id:
        return True, 'ok'
    looks_cccd = any(kw in upper for kw in _CCCD_KW)
    if looks_cccd and (fields.get('expiry') or fields.get('home') or fields.get('issue_date') or has_name):
        return True, 'ok'
    return False, 'Không nhận ra CCCD — cần thấy số CCCD 12 số rõ trên ảnh'


# ── Document type detection ───────────────────────────────────────────────────

_CCCD_KW = [
    'CĂN CƯỚC', 'CCCD', 'CÔNG DÂN', 'CITIZEN', 'IDENTITY CARD',
    'CAN CUOC', 'CĂN CƯỚC CÔNG DÂN',
    # Mặt sau CCCD thường có MRZ / chip / đặc điểm nhân dạng
    'CHARACTERISTICS', 'ĐẶC ĐIỂM', 'DAC DIEM', 'PERSONAL IDENTIFICATION',
    'QR', 'CHIP', 'IDVNM', 'VNM',
]
_LICENSE_KW = [
    'GIẤY PHÉP LÁI XE', 'GPLX', 'DRIVER', 'LÁI XE', 'DRIVING',
    'LICENCE', 'LICENSE', 'PERMIS', 'HẠNG',
]
_CLASS_RE = re.compile(r'\b(A1|A2|B1|B2|[CDEF])\b', re.IGNORECASE)


def _detect_type(text: str) -> str:
    upper = text.upper()
    lic_hits = sum(1 for kw in _LICENSE_KW if kw in upper)
    cccd_hits = sum(1 for kw in _CCCD_KW if kw in upper)
    class_hit = bool(_CLASS_RE.search(text[:400]))

    if lic_hits > cccd_hits or (class_hit and lic_hits >= cccd_hits):
        return 'license'
    if cccd_hits > 0:
        return 'cccd'
    if class_hit:
        return 'license'
    return 'unknown'


# ── Shared helpers ────────────────────────────────────────────────────────────

def _nd(s: str) -> str:
    """Normalize date separators to '/'."""
    return s.replace('-', '/').replace('.', '/')


def _extract_date(text: str, labels: list[str]) -> str | None:
    for label in labels:
        m = re.search(
            rf'(?:{label})[:\s/]*(\d{{1,2}}[/\-\.]\d{{1,2}}[/\-\.]\d{{4}})',
            text, re.IGNORECASE,
        )
        if m:
            return _nd(m.group(1))
    m = re.search(r'\b(\d{2}/\d{2}/\d{4})\b', text)
    return _nd(m.group(1)) if m else None


def _extract_name(text: str, labels: list[str]) -> str | None:
    UPPER_VI = r'A-ZĐÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝĂẮẶẰẴẲƠỚỢỜỠỞƯỨỰỪỮỬ'
    for label in labels:
        m = re.search(
            rf'(?:{label})[:\s]*([{UPPER_VI}\s]{{3,50}})',
            text, re.IGNORECASE,
        )
        if m:
            name = m.group(1).strip()
            if 3 <= len(name) <= 50:
                return name
    return None


# ── CCCD parser ───────────────────────────────────────────────────────────────

def _parse_cccd(text: str) -> dict:
    result = {}

    m = re.search(r'\b(\d{12})\b', text)
    if m:
        result['id'] = m.group(1)

    d = _extract_date(text, ['Ngày sinh', 'Date of birth', 'sinh'])
    if d:
        result['birth_day'] = d

    n = _extract_name(text, ['Họ và tên', 'Full name', 'HỌ VÀ TÊN'])
    if n:
        result['name'] = n

    m = re.search(r'(?:Có giá trị đến|Date of expiry|giá trị đến)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4})', text, re.IGNORECASE)
    if m:
        result['expiry'] = _nd(m.group(1))

    m = re.search(r'(?:Nơi thường trú|Place of residence)[:\s]*([^\n]{5,100})', text, re.IGNORECASE)
    if m:
        result['home'] = m.group(1).strip()

    m = re.search(r'(?:Quê quán|Place of origin)[:\s]*([^\n]{5,100})', text, re.IGNORECASE)
    if m:
        result['origin'] = m.group(1).strip()

    m = re.search(r'(?:Ngày cấp|Date of issue)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4})', text, re.IGNORECASE)
    if m:
        result['issue_date'] = _nd(m.group(1))

    return result


# ── Driving license parser ────────────────────────────────────────────────────

def _parse_license(text: str) -> dict:
    result = {}

    m = re.search(r'\b(\d{12})\b', text)
    if m:
        result['id'] = m.group(1)

    n = _extract_name(text, ['Họ và tên', 'Họ tên', 'Full name', 'HỌ VÀ TÊN', 'HỌ TÊN'])
    if n:
        result['name'] = n

    d = _extract_date(text, ['Ngày sinh', 'Date of birth', 'sinh'])
    if d:
        result['birth_day'] = d

    m = re.search(
        r'(?:Hạng|Hang|Class|HẠNG|LOẠI)[:\s]*([A-F][12]?(?:[,;\s/]+[A-F][12]?)*)',
        text, re.IGNORECASE,
    )
    if m:
        result['type'] = m.group(1).strip().upper()
    else:
        m = _CLASS_RE.search(text)
        if m:
            result['type'] = m.group(0).upper()

    m = re.search(
        r'(?:Có giá trị đến|Valid until|Date of expiry|giá trị đến|đến ngày|Hết hạn)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4})',
        text, re.IGNORECASE,
    )
    if m:
        result['expiry'] = _nd(m.group(1))

    m = re.search(
        r'(?:Ngày cấp|Date of issue|Cấp ngày)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4})',
        text, re.IGNORECASE,
    )
    if m:
        result['issue_date'] = _nd(m.group(1))

    m = re.search(
        r'(?:Nơi cấp|Issued by|Cơ quan cấp)[:\s]*([^\n]{5,80})',
        text, re.IGNORECASE,
    )
    if m:
        result['home'] = m.group(1).strip()

    m = re.search(r'(?:Quốc tịch|Nationality)[:\s]*([^\n]{2,30})', text, re.IGNORECASE)
    if m:
        result['nationality'] = m.group(1).strip()

    m = re.search(r'(?:Nơi cư trú|Địa chỉ|Address)[:\s]*([^\n]{5,100})', text, re.IGNORECASE)
    if m:
        result['address'] = m.group(1).strip()

    return result
