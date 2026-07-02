# eKYC Local Service

Python FastAPI service — fallback khi ViettelAI không khả dụng.

## Chạy bằng Docker (khuyến nghị)

```bash
cd ekyc-service

# Build + chạy (lần đầu ~10–15 phút do download models)
docker-compose up --build

# Lần sau chỉ cần:
docker-compose up
```

Service chạy tại `http://localhost:8001`

## Test thủ công

```bash
# Health check
curl http://localhost:8001/health

# OCR CCCD (thay đường dẫn ảnh)
curl -X POST http://localhost:8001/ocr \
  -F "file=@/path/to/cccd_front.jpg"

# OCR Bằng lái
curl -X POST http://localhost:8001/ocr \
  -F "file=@/path/to/license_front.jpg"

# Liveness check
curl -X POST http://localhost:8001/liveness \
  -F "file=@/path/to/selfie.jpg"

# Spoof check (giấy tờ)
curl -X POST http://localhost:8001/spoof-check \
  -F "file=@/path/to/document.jpg"

# Face match (selfie vs ảnh CCCD)
curl -X POST http://localhost:8001/face-match \
  -F "face=@/path/to/selfie.jpg" \
  -F "id_image=@/path/to/cccd_front.jpg"
```

## Response format (mirror ViettelAI)

```json
{
  "code": 200,
  "data": {
    "id": "012345678901",
    "name": "NGUYEN VAN A",
    "birth_day": "01/01/1990",
    "home": "Hà Nội",
    "expiry": "01/01/2030",
    "issue_date": "01/01/2020",
    "doc_type": "cccd"
  }
}
```

## Endpoints

| Method | Path | Input | Output |
|---|---|---|---|
| GET | `/health` | — | `{status: ok}` |
| POST | `/ocr` | `file` (image) | CCCD/license fields |
| POST | `/face-match` | `face`, `id_image` | similarity score |
| POST | `/liveness` | `file` (selfie) | `is_live`, score |
| POST | `/spoof-check` | `file` (document) | `is_fake`, score |

## Models

| Task | Library | Model |
|---|---|---|
| OCR | EasyOCR | CRAFT + CRNN vi+en |
| Face match | DeepFace | Facenet512 (cosine) |
| Liveness | MediaPipe | FaceMesh 468 landmarks |
| Spoof | OpenCV | DFT + texture analysis |
