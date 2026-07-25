# eKYC — Cách hoạt động (GoRento)

## Mục tiêu

Khách thuê xác minh danh tính qua **5 bước** trước khi thuê xe:

1. CCCD mặt trước  
2. CCCD mặt sau  
3. Bằng lái mặt trước  
4. Bằng lái mặt sau  
5. Selfie  

Đủ 5 bước → `user_verifications.status = VERIFIED`.

---

## Kiến trúc

```
Flutter (image_picker)
        │ multipart
        ▼
Spring  /api/verification/*
        │
        ▼
EkycService  (ekyc.mode=local | mock)
        │
        ▼
LocalEkycAdapter  →  http://localhost:8001  (EasyOCR)
```

| Mode | Khi nào dùng |
|------|----------------|
| `local` (mặc định) | Gọi EasyOCR trên `ekyc-service` |
| `mock` | Demo offline hoàn toàn |

```properties
ekyc.mode=local
ekyc.local-service-url=http://localhost:8001
```

**Không dùng ViettelAI.** Adapter/code legacy (nếu còn trong repo) không được wire trong `EkycService`.

---

## Soft-pass (demo)

Để khách dễ hoàn tất 5 bước khi demo / ảnh chất lượng thấp:

- Upload ảnh CCCD / bằng / selfie **được chấp nhận** (không chặn vì “ảnh mờ”).
- OCR vẫn chạy khi service sống; nếu đọc được sẽ lưu số CCCD / tên.
- Spoof / liveness / face-match **không** làm fail bước upload trong chế độ hiện tại.

Production thật: siết lại ngưỡng spoof/OCR khi có vendor ổn định.

---

## Chạy OCR service

```bash
cd ekyc-service
python -m venv .venv
.venv\Scripts\pip install -r requirements-ocr.txt
.venv\Scripts\python ocr_server.py
```

Health: `GET http://localhost:8001/health`

---

## API

| Path | Ý nghĩa |
|------|---------|
| `POST /api/verification/cccd` | Mặt trước CCCD |
| `POST /api/verification/cccd/back` | Mặt sau CCCD |
| `POST /api/verification/license` | Mặt trước GPLX |
| `POST /api/verification/license/back` | Mặt sau GPLX |
| `POST /api/verification/face` | Selfie |
| `GET /api/verification/status` | Trạng thái 5 bước |

Kết quả lưu bảng `user_verifications` (không lưu file ảnh lâu dài).
