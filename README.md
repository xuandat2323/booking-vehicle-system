# GoRento — Hệ thống thuê xe tự lái tại chi nhánh

Spring Boot API + Flutter (Web / Android / iOS).

---

## Tính năng

| Nhóm | Chi tiết |
|------|----------|
| **Auth** | Đăng nhập SĐT + mật khẩu; đăng ký OTP (mock / Firebase) |
| **eKYC** | 5 bước: CCCD trước/sau, bằng lái trước/sau, selfie (EasyOCR local) |
| **Chi nhánh** | 3 cơ sở (Hoàn Kiếm, Cầu Giấy, Thanh Xuân) — xe chỉ thuộc các chi nhánh này |
| **Xe** | Tìm theo chi nhánh, lọc hãng/giá/chỗ |
| **Đặt xe** | Chọn ngày, điểm đón/trả **tại chi nhánh**, đặt cọc |
| **Thanh toán** | PayOS / VietQR (có chế độ demo) |
| **Admin** | Dashboard, CRUD người dùng / xe / đơn / gán chi nhánh |
| **Chatbot** | Gợi ý xe (Gemini nếu có key, không thì keyword) |
| **Thông báo** | FCM + in-app |

> Chỉ hai role: **USER** và **ADMIN**.

---

## Tech stack

**Backend** (`backend/`)
- Java 17, Spring Boot 3, Security + JWT
- MySQL 8 + Flyway
- Cloudinary (ảnh xe), PayOS, Goong (geo), Firebase Admin (tuỳ chọn)

**Mobile** (`flutter_app/`)
- Flutter 3, Riverpod, Dio, GoRouter
- flutter_map + Goong/Carto, Firebase Auth/Messaging

---

## Cấu trúc

```
├── backend/                 # Spring Boot API :8080
├── flutter_app/             # Flutter client
├── ekyc-service/            # EasyOCR local :8001
├── docs/
│   └── eKYC.md
└── README.md
```

---

## Luồng chính (USER)

```
Đăng ký / Đăng nhập
  → eKYC (5 bước) → VERIFIED
  → Chọn chi nhánh / tìm xe
  → Tạo đơn (đón/trả tại chi nhánh) → Đặt cọc PayOS
  → Admin xác nhận → Nhận xe / Trả xe → Review → Hóa đơn
```

**ADMIN:** Trang chủ quản trị → Người dùng / Xe (gán chi nhánh) / Đơn. Không có tab Tìm xe / Chuyến đi / Hóa đơn / chatbot của USER.

---

## 3 chi nhánh (seed)

| Chi nhánh | Địa chỉ |
|-----------|---------|
| GoRento Hoàn Kiếm | Số 1 Tràng Tiền, Hoàn Kiếm, Hà Nội |
| GoRento Cầu Giấy | Số 15 Duy Tân, Cầu Giấy, Hà Nội |
| GoRento Thanh Xuân | Số 201 Nguyễn Trãi, Thanh Xuân, Hà Nội |

Xe luôn gắn `branch_id`; điểm đón/trả khi book chỉ chọn trong 3 chi nhánh.

---

## Chạy nhanh

### 1. MySQL

```sql
CREATE DATABASE vehicle_booking CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2. Backend

```bash
cd backend
copy .env.example .env
# Điền MySQL, PayOS, Goong...

gradlew.bat bootRun --args="--spring.profiles.active=dev"
```

Swagger: `http://localhost:8080/swagger-ui.html`

### 3. eKYC OCR (tuỳ chọn)

```bash
cd ekyc-service
# kích hoạt venv rồi:
python ocr_server.py
```

### 4. Flutter

```bash
cd flutter_app
copy .env.json.example .env.json
flutter pub get
flutter run -d chrome --dart-define-from-file=.env.json
```

---

## Tài khoản demo

| Role | SĐT | Mật khẩu |
|------|-----|----------|
| ADMIN | `+84987654321` | `Password123!` |
| USER | `+84123456789` | `Password123!` |

OTP mock: `123456`.

---

## Thanh toán

Mặc định `PAYOS_MODE=mock` trong `backend/.env` — màn QR VietQR + nút demo xác nhận cọc.  
Live: điền `PAYOS_CLIENT_ID` / `API_KEY` / `CHECKSUM_KEY`, đặt `PAYOS_MODE=live`, webhook ngrok → `/api/payments/payos/webhook`.

---

## eKYC

Chi tiết: **[docs/eKYC.md](docs/eKYC.md)**.  
`ekyc.mode=local` → EasyOCR port 8001. Upload ảnh được soft-pass để demo dễ hoàn tất 5 bước.

---

## API chính

| Method | Endpoint | Auth |
|--------|----------|------|
| POST | `/api/auth/login` | — |
| GET | `/api/branches` | — |
| GET | `/api/cars` | — |
| GET/POST | `/api/bookings/**` | USER |
| POST | `/api/payments/payos/**` | USER (+ webhook public) |
| POST | `/api/verification/**` | authenticated |
| GET/POST/PUT/DELETE | `/api/admin/**` | ADMIN |

---

## File môi trường (gitignore)

| File | Mục đích |
|------|----------|
| `backend/.env` | DB keys, PayOS, Goong… |
| `flutter_app/.env.json` | `BASE_URL`, Goong map |
| `backend/.../firebase-service-account.json` | Firebase (tuỳ chọn) |
