import re
import numpy as np
import easyocr

_reader = None

def get_reader():
    global _reader
    if _reader is None:
        _reader = easyocr.Reader(['vi', 'en'], gpu=False)
    return _reader


def ocr_image(image_np: np.ndarray) -> dict:
    reader = get_reader()
    raw = reader.readtext(image_np, detail=0, paragraph=True)
    text = '\n'.join(raw)

    doc_type = _detect_type(text)
    fields = _parse_license(text) if doc_type == 'license' else _parse_cccd(text)
    fields['doc_type'] = doc_type

    success = bool(fields.get('id') or fields.get('name'))
    return {
        'code': 200 if success else 422,
        'data': fields if success else {},
        'raw_text': text,
    }


# ── Document type detection ───────────────────────────────────────────────────

_CCCD_KW    = ['CĂN CƯỚC', 'CCCD', 'CÔNG DÂN', 'CITIZEN', 'IDENTITY CARD', 'CAN CUOC']
_LICENSE_KW = ['GIẤY PHÉP LÁI XE', 'GPLX', 'DRIVER', 'LÁI XE']
_CLASS_RE   = re.compile(r'\b(A1|A2|B1|B2|[CDEF])\b', re.IGNORECASE)


def _detect_type(text: str) -> str:
    upper = text.upper()
    for kw in _CCCD_KW:
        if kw in upper:
            return 'cccd'
    for kw in _LICENSE_KW:
        if kw in upper:
            return 'license'
    # If a license class appears early in the text → likely a license
    m = _CLASS_RE.search(text[:300])
    if m:
        return 'license'
    return 'cccd'


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
    # Fallback: any DD/MM/YYYY standalone
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
    """
    Parse Vietnamese Giấy phép lái xe.
    Fields differ from CCCD: license class, issuing authority, nationality.
    """
    result = {}

    # ID / license number — 12 digits
    m = re.search(r'\b(\d{12})\b', text)
    if m:
        result['id'] = m.group(1)

    # Full name
    n = _extract_name(text, ['Họ và tên', 'Họ tên', 'Full name', 'HỌ VÀ TÊN', 'HỌ TÊN'])
    if n:
        result['name'] = n

    # Date of birth
    d = _extract_date(text, ['Ngày sinh', 'Date of birth', 'sinh'])
    if d:
        result['birth_day'] = d

    # License class — A1, A2, B1, B2, C, D, E, F (may have multiple separated by comma)
    m = re.search(
        r'(?:Hạng|Hang|Class|HẠNG|LOẠI)[:\s]*([A-F][12]?(?:[,;\s/]+[A-F][12]?)*)',
        text, re.IGNORECASE,
    )
    if m:
        result['type'] = m.group(1).strip().upper()
    else:
        # Fallback: isolated class letter near keywords
        m = _CLASS_RE.search(text)
        if m:
            result['type'] = m.group(0).upper()

    # Expiry
    m = re.search(
        r'(?:Có giá trị đến|Valid until|Date of expiry|giá trị đến|đến ngày|Hết hạn)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4})',
        text, re.IGNORECASE,
    )
    if m:
        result['expiry'] = _nd(m.group(1))

    # Issue date
    m = re.search(
        r'(?:Ngày cấp|Date of issue|Cấp ngày)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4})',
        text, re.IGNORECASE,
    )
    if m:
        result['issue_date'] = _nd(m.group(1))

    # Issuing authority / nơi cấp
    m = re.search(
        r'(?:Nơi cấp|Issued by|Cơ quan cấp)[:\s]*([^\n]{5,80})',
        text, re.IGNORECASE,
    )
    if m:
        result['home'] = m.group(1).strip()

    # Nationality
    m = re.search(r'(?:Quốc tịch|Nationality)[:\s]*([^\n]{2,30})', text, re.IGNORECASE)
    if m:
        result['nationality'] = m.group(1).strip()

    # Residence / address
    m = re.search(r'(?:Nơi cư trú|Địa chỉ|Address)[:\s]*([^\n]{5,100})', text, re.IGNORECASE)
    if m:
        result['address'] = m.group(1).strip()

    return result
