# eKYC AI Plan — GoRento

> Kế hoạch thay thế / nâng cấp module eKYC hiện tại (ViettelAI) bằng mô hình AI mạnh hơn, kiểm soát được, và không phụ thuộc vendor.

---

## 1. Hiện Trạng

Hệ thống đang dùng **ViettelAI eKYC API** (`https://viettelai.vn/ekyc`) cho 3 tác vụ:

| Tác vụ | Endpoint | Vấn đề |
|--------|----------|--------|
| Spoof check (giả mạo giấy tờ) | `/id_spoof_check` | Token hết hạn thường xuyên, không tự renew |
| OCR CCCD / bằng lái | `/id_card` | Độ chính xác thấp với ảnh chụp nghiêng / mờ |
| Liveness detection | `/liveness_check` | Không hoạt động ổn định trên mobile |
| Face matching | `/face_matching` | Phụ thuộc hoàn toàn vendor |

**Hạn chế chính:**
- Phụ thuộc vendor nước ngoài, khó kiểm soát SLA
- Token quản lý thủ công, không có cơ chế tự refresh
- Chi phí tăng theo lượng request, không có tier free đủ dùng
- Không thể fine-tune cho đặc thù CCCD Việt Nam (chứng minh nhân dân cũ, CCCD gắn chip mới)

---

## 2. Mục Tiêu

1. **Độ chính xác ≥ 95%** với CCCD/bằng lái Việt Nam
2. **Không vendor lock-in** — có thể tự host hoặc đổi provider
3. **Chi phí thấp** — ưu tiên mô hình mã nguồn mở hoặc API có free tier
4. **Kiểm soát dữ liệu** — không gửi ảnh CCCD lên server nước ngoài (tuân thủ PDPA)

---

## 3. Kiến Trúc Đề Xuất

```
Mobile App
    │  upload ảnh
    ▼
Backend (Spring Boot)
    ├── OCR Service          ──► PaddleOCR / Google Vision API
    ├── Face Match Service   ──► InsightFace (self-hosted) / AWS Rekognition
    ├── Liveness Service     ──► MediaPipe FaceDetection (on-device) / FaceTec
    └── Spoof Check Service  ──► DeepFace / custom CNN model
```

**Nguyên tắc:** Xử lý trên backend, không gửi ảnh nhạy cảm qua bên thứ ba nếu không cần thiết.

---

## 4. Lựa Chọn Model Theo Tác Vụ

### 4.1 OCR — Nhận dạng văn bản CCCD / Bằng lái

| Option | Loại | Độ chính xác VN | Chi phí | Khuyến nghị |
|--------|------|-----------------|---------|-------------|
| **PaddleOCR** | Self-hosted, open-source | ★★★★☆ | Miễn phí | ✅ Tốt nhất |
| **Google Vision API** | Cloud API | ★★★★★ | $1.5/1000 req | ✅ Dự phòng |
| **AWS Textract** | Cloud API | ★★★★☆ | $1.5/1000 req | — |
| **Tesseract** | Self-hosted, open-source | ★★★☆☆ | Miễn phí | ❌ Kém tiếng Việt |
| **EasyOCR** | Self-hosted, open-source | ★★★★☆ | Miễn phí | ✅ Backup |

**Chọn:** PaddleOCR (PP-OCRv4) self-hosted + Google Vision API làm fallback.

**Lý do:** PaddleOCR hỗ trợ tiếng Việt tốt, model nhỏ (~30MB), chạy được trên server thường. Đã được cộng đồng fine-tune cho CCCD Việt Nam.

---

### 4.2 Face Matching — Khớp khuôn mặt selfie vs CCCD

| Option | Loại | Độ chính xác | Chi phí | Khuyến nghị |
|--------|------|-------------|---------|-------------|
| **InsightFace (ArcFace)** | Self-hosted, open-source | ★★★★★ | Miễn phí | ✅ Tốt nhất |
| **AWS Rekognition** | Cloud API | ★★★★★ | $0.001/req | ✅ Dự phòng |
| **Azure Face API** | Cloud API | ★★★★★ | $1/1000 req | — |
| **DeepFace** | Self-hosted, open-source | ★★★★☆ | Miễn phí | ✅ Dễ tích hợp |
| **FaceNet (TensorFlow)** | Self-hosted, open-source | ★★★★☆ | Miễn phí | — |

**Chọn:** InsightFace với model `buffalo_l` self-hosted.

**Lý do:** Benchmark LFW accuracy 99.77%, hỗ trợ REST API qua `insightface-rest`, nhẹ hơn FaceNet. Threshold khuyến nghị: cosine similarity ≥ 0.4.

---

### 4.3 Liveness Detection — Phát hiện khuôn mặt thật

| Option | Loại | Phương pháp | Chi phí | Khuyến nghị |
|--------|------|------------|---------|-------------|
| **MediaPipe** (on-device) | Mobile SDK | Passive | Miễn phí | ✅ Nhanh nhất |
| **Silent Face Anti-Spoofing** | Self-hosted | Passive | Miễn phí | ✅ Server-side |
| **FaceTec** | Cloud SDK | Active (3D) | Trả phí | Quá mức cần |
| **AWS Rekognition** | Cloud API | Passive | $0.001/req | ✅ Dự phòng |

**Chọn:** MediaPipe FaceDetection trên Flutter (on-device, không cần network) + Silent Face Anti-Spoofing trên server làm lớp kiểm tra thứ 2.

**Lý do:** On-device xử lý nhanh (~30ms), không gửi ảnh qua mạng. Server-side làm lớp bảo vệ thêm cho ảnh upload.

---

### 4.4 Document Spoof Detection — Phát hiện giấy tờ giả

| Option | Loại | Chi phí | Khuyến nghị |
|--------|------|---------|-------------|
| **Custom CNN (EfficientNet)** | Self-trained | Chi phí training | ✅ Tốt nhất dài hạn |
| **DocShadow / DocTR** | Self-hosted | Miễn phí | ✅ Ngắn hạn |
| **AWS Rekognition** | Cloud API | $0.001/req | — |

**Chọn:** DocTR ngắn hạn, fine-tune EfficientNet dài hạn.

---

## 5. Kế Hoạch Training (cho model tự huấn luyện)

### 5.1 Dữ liệu cần thu thập

| Loại ảnh | Số lượng tối thiểu | Ghi chú |
|----------|--------------------|---------|
| CCCD chip (2021+) mặt trước | 1,000 ảnh | Ảnh thật từ user có consent |
| CCCD chip mặt sau | 1,000 ảnh | |
| CMND 9 số cũ | 500 ảnh | Legacy |
| Bằng lái B1, B2 | 500 ảnh | |
| Ảnh giả (in từ màn hình) | 500 ảnh | Negative samples |
| Ảnh photocopy | 500 ảnh | Negative samples |

> **Lưu ý pháp lý:** Thu thập và lưu trữ ảnh CCCD phải có **consent rõ ràng** từ người dùng và tuân thủ Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân.

### 5.2 Pipeline Training

```
Thu thập dữ liệu
    │
    ▼
Tiền xử lý (crop, normalize, augmentation)
    │  ├── Random rotation ±15°
    │  ├── Brightness/contrast jitter
    │  ├── Gaussian blur (mô phỏng ảnh mờ)
    │  └── Perspective transform (mô phỏng ảnh nghiêng)
    ▼
Huấn luyện model
    │  ├── OCR: Fine-tune PaddleOCR PP-OCRv4 trên tập CCCD VN
    │  └── Spoof: Fine-tune EfficientNet-B0 (binary classifier)
    ▼
Đánh giá (validation set 20%)
    │  ├── OCR: Character Error Rate (CER) < 5%
    │  └── Spoof: Precision/Recall > 95%
    ▼
Deploy (ONNX export → FastAPI / TorchServe)
```

### 5.3 Công cụ

| Mục đích | Tool |
|----------|------|
| Training framework | PyTorch / PaddlePaddle |
| Experiment tracking | MLflow / Weights & Biases |
| Data labeling | Label Studio |
| Model serving | FastAPI + ONNX Runtime |
| Containerization | Docker |

---

## 6. Kiến Trúc Tích Hợp Backend

```java
// Thay ViettelAiService bằng EkycService với các adapter

interface EkycProvider {
    OcrResult ocr(MultipartFile file);
    FaceMatchResult faceMatch(MultipartFile face, MultipartFile idCard);
    LivenessResult liveness(MultipartFile face);
    SpoofResult spoofCheck(MultipartFile file);
}

// Implementations:
class PaddleOcrAdapter implements EkycProvider { ... }
class InsightFaceAdapter implements EkycProvider { ... }
class GoogleVisionFallbackAdapter implements EkycProvider { ... }
```

Backend gọi local Python microservice (FastAPI) qua HTTP:

```
Spring Boot ──HTTP──► FastAPI (Python)
                           ├── /ocr        → PaddleOCR
                           ├── /face-match → InsightFace
                           ├── /liveness   → Silent Face Anti-Spoofing
                           └── /spoof      → EfficientNet / DocTR
```

---

## 7. Roadmap Thực Hiện

| Giai đoạn | Việc cần làm | Thời gian ước tính |
|-----------|-------------|-------------------|
| **Phase 1** | Setup FastAPI service, tích hợp PaddleOCR + InsightFace | 1–2 tuần |
| **Phase 2** | Thay ViettelAiService bằng adapter pattern, test end-to-end | 1 tuần |
| **Phase 3** | Thu thập dữ liệu CCCD VN, label với Label Studio | 2–4 tuần |
| **Phase 4** | Fine-tune PaddleOCR trên CCCD VN, đánh giá CER | 2 tuần |
| **Phase 5** | Training Spoof Detection (EfficientNet) | 2 tuần |
| **Phase 6** | Tích hợp MediaPipe on-device liveness vào Flutter | 1 tuần |
| **Phase 7** | Load test, monitor, deploy production | 1 tuần |

**Tổng ước tính:** 10–13 tuần (phụ thuộc vào tốc độ thu thập dữ liệu)

---

## 8. So Sánh Chi Phí

| Phương án | Chi phí/tháng (10k request) | Kiểm soát data | Độ chính xác VN |
|-----------|----------------------------|----------------|-----------------|
| ViettelAI (hiện tại) | ~$50–200 | Thấp | ★★★☆☆ |
| Google Vision + AWS Rekognition | ~$30–50 | Trung bình | ★★★★★ |
| Self-hosted (Phase 1–2) | $20–50 (server) | Cao | ★★★★☆ |
| Self-hosted + fine-tuned (Phase 4–5) | $20–50 (server) | Cao | ★★★★★ |

---

## 9. Bước Tiếp Theo Ngay

1. **Ngắn hạn (1–2 tuần):**
   - Dựng FastAPI service với PaddleOCR + InsightFace bằng Docker
   - Refactor `ViettelAiService.java` thành interface `EkycProvider`
   - Test với ảnh CCCD thật để đánh giá baseline accuracy

2. **Trung hạn (1–2 tháng):**
   - Thu thập dataset CCCD (có consent)
   - Fine-tune PaddleOCR
   - Tích hợp MediaPipe liveness vào Flutter

3. **Dài hạn:**
   - Xây dựng pipeline CI/CD cho model retraining
   - Monitor accuracy drift theo thời gian
