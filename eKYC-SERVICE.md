# eKYC Service — Tài Liệu Kỹ Thuật

Microservice Python chạy độc lập, dùng làm fallback khi ViettelAI không khả dụng.  
Cung cấp 4 chức năng: OCR giấy tờ, so khớp khuôn mặt, liveness detection, chống giả mạo tài liệu.

---

## Kiến Trúc

```
Flutter App
    │
    ▼
Spring Boot Backend ──► ViettelAI API (ưu tiên 1)
         │
         └──► eKYC Local Service :8001 (fallback — khi ViettelAI lỗi / hết quota)
                      │
                 ┌────┴────────────────┐
                 │                    │
              EasyOCR             DeepFace
           (đọc CCCD/GPLX)    (so khớp khuôn mặt)
                                    │
                               MediaPipe
                             (liveness check)
```

**Backend tự chọn provider** theo thứ tự ưu tiên trong `VerificationController`:
1. ViettelAI (nếu `viettelai.token` được cấu hình và phản hồi thành công)
2. Local eKYC Service tại `ekyc.local-service-url` (fallback)

---

## Công Nghệ

| Thư viện | Phiên bản | Mục đích |
|----------|-----------|----------|
| FastAPI | 0.115.0 | HTTP server |
| EasyOCR | 1.7.1 | OCR tiếng Việt — đọc thông tin CCCD, bằng lái |
| DeepFace | 0.0.93 | So khớp khuôn mặt (model Facenet512) |
| tf-keras | 2.16.0 | Backend cho DeepFace |
| OpenCV | 4.10.0 | Xử lý ảnh |
| MediaPipe | 0.10.14 | Liveness detection (face mesh) |
| NumPy | 1.26.4 | Tính toán ma trận |

---

## Yêu Cầu Cài Đặt

- Docker + Docker Compose (khuyến nghị)
- Hoặc Python 3.10+ (chạy thủ công)
- RAM tối thiểu: **4GB** (EasyOCR + DeepFace model khá nặng)
- Lần chạy đầu tiên tải model về ~500MB

---

## Chạy với Docker Compose *(khuyến nghị)*

```bash
cd ekyc-service
docker-compose up -d
```

Kiểm tra:
```bash
curl http://localhost:8001/health
# → {"status":"ok"}
```

---

## Chạy Thủ Công (không có Docker)

```bash
cd ekyc-service

# Tạo virtual env
python -m venv venv

# Kích hoạt
# Windows
venv\Scripts\activate
# macOS / Linux
source venv/bin/activate

# Cài dependencies
pip install -r requirements.txt

# Chạy
uvicorn main:app --host 0.0.0.0 --port 8001
```

---

## API Endpoints

Base URL: `http://localhost:8001`

### `GET /health`

Kiểm tra service còn sống.

**Response:**
```json
{ "status": "ok" }
```

---

### `POST /ocr`

OCR ảnh CCCD hoặc bằng lái xe, trả về thông tin text đã trích xuất.

**Request:** `multipart/form-data`

| Field | Type | Mô tả |
|-------|------|-------|
| `file` | file | Ảnh CCCD hoặc bằng lái (JPG/PNG) |

**Response:**
```json
{
  "code": 200,
  "data": {
    "id": "001234567890",
    "name": "NGUYEN VAN A",
    "dob": "01/01/1990",
    "address": "...",
    "raw_text": ["001234567890", "NGUYEN VAN A", ...]
  }
}
```

---

### `POST /face-match`

So khớp khuôn mặt selfie với ảnh trên giấy tờ.  
Dùng model **Facenet512** với cosine distance. Threshold: `0.30` (similarity > 70% → cùng người).

**Request:** `multipart/form-data`

| Field | Type | Mô tả |
|-------|------|-------|
| `face` | file | Ảnh selfie của người dùng |
| `id_image` | file | Ảnh chân dung trên CCCD / bằng lái |

**Response:**
```json
{
  "code": 200,
  "data": {
    "similarity": 0.8542,
    "score": 0.8542,
    "verified": true,
    "distance": 0.1458
  }
}
```

| Field | Mô tả |
|-------|-------|
| `similarity` | Độ tương đồng (0–1), > 0.70 là cùng người |
| `verified` | `true` nếu distance < 0.30 |
| `distance` | Cosine distance (càng nhỏ càng giống) |

---

### `POST /liveness`

Kiểm tra khuôn mặt thật (không phải ảnh in, màn hình điện thoại).  
Dùng **MediaPipe Face Mesh** để phân tích cấu trúc 3D.

**Request:** `multipart/form-data`

| Field | Type | Mô tả |
|-------|------|-------|
| `file` | file | Ảnh selfie |

**Response:**
```json
{
  "code": 200,
  "data": {
    "is_live": true,
    "confidence": 0.91
  }
}
```

---

### `POST /spoof-check`

Phát hiện tài liệu giả mạo (CCCD/bằng lái bị in ra hoặc chụp lại từ màn hình).

**Request:** `multipart/form-data`

| Field | Type | Mô tả |
|-------|------|-------|
| `file` | file | Ảnh tài liệu cần kiểm tra |

**Response:**
```json
{
  "code": 200,
  "data": {
    "is_genuine": true,
    "spoof_score": 0.08
  }
}
```

---

## Luồng eKYC Đầy Đủ

```
1. Upload CCCD mặt trước  ──► POST /api/verification/cccd
        │
        ▼
2. Upload CCCD mặt sau    ──► POST /api/verification/cccd/back

3. Upload GPLX mặt trước  ──► POST /api/verification/license
        │
        ▼
4. Upload GPLX mặt sau    ──► POST /api/verification/license/back

5. Chụp selfie            ──► POST /api/verification/face
   (so khớp với ảnh CCCD)
        │
        ▼
6. Backend chuyển status = PENDING
   Admin / hệ thống duyệt → VERIFIED / REJECTED
```

---

## Cấu Hình Backend

Trong `application-dev.properties`:

```properties
# URL của local eKYC service (fallback)
ekyc.local-service-url=http://localhost:8001

# ViettelAI (ưu tiên 1 — để trống nếu không có)
viettelai.token=YOUR_TOKEN
```

Nếu `viettelai.token` rỗng hoặc ViettelAI trả lỗi, backend tự động chuyển sang gọi `ekyc.local-service-url`.

---

## Lưu Ý

- **Lần đầu chạy chậm**: EasyOCR và DeepFace tải model (~500MB). Các lần sau nhanh hơn do cache.
- **Độ chính xác OCR**: EasyOCR hoạt động tốt với ảnh chụp rõ, ánh sáng đủ. Ảnh mờ, nghiêng nhiều có thể sai.
- **Liveness**: MediaPipe detect face mesh 3D — ảnh selfie 2D thường không qua được. Cần ảnh chụp thật từ camera.
- **Docker vs thủ công**: Docker cô lập môi trường tốt hơn, tránh xung đột thư viện Python.
