# GoRento — Hệ Thống Thuê Xe Tự Lái

Spring Boot API + Flutter Mobile App (Android/iOS).

---

## Tính Năng

| Nhóm | Chi tiết |
|------|----------|
| **Auth** | Đăng ký / đăng nhập bằng SĐT + OTP (mock / Firebase / Twilio) |
| **eKYC** | Xác minh CCCD, bằng lái xe, nhận diện khuôn mặt |
| **Xe** | Tìm kiếm, lọc, xem chi tiết, ảnh xe |
| **Đặt xe** | Chọn ngày, điểm đón/trả trên bản đồ |
| **Thanh toán** | VNPay sandbox (webview mobile + xác nhận JSON) |
| **Tracking** | Định vị GPS thời gian thực (Goong Maps) |
| **Review** | Đánh giá sau khi trả xe |
| **Chủ xe** | Dashboard, quản lý xe + ảnh, duyệt đơn |
| **Admin** | Quản lý user, xe, đơn đặt, hóa đơn |
| **Thông báo** | Push notification qua FCM + in-app |

---

## Tech Stack

**Backend** — `backend/`
- Java 21, Spring Boot 3, Spring Security + JWT
- MySQL 8 + Flyway, Hibernate
- Cloudinary (ảnh), VNPay (thanh toán), Firebase Admin SDK (FCM + OTP), ViettelAI eKYC

**Mobile** — `flutter_app/`
- Flutter 3, Riverpod, Dio, GoRouter
- flutter_map + Goong Maps tile
- firebase_auth, firebase_messaging, image_picker, flutter_secure_storage

**eKYC Service** — `ekyc-service/`
- Python (FastAPI), OpenCV, DeepFace
- Docker Compose (fallback khi ViettelAI không khả dụng)

---

## Cấu Trúc Dự Án

```
vehicle-booking-system/
├── backend/
│   ├── build.gradle
│   ├── gradlew / gradlew.bat
│   └── src/main/
│       ├── java/vehicle/booking/
│       │   ├── config/          # Security, Firebase, VNPay, Cloudinary
│       │   ├── controller/      # REST controllers (auth, car, booking, payment...)
│       │   │   └── admin/       # Admin endpoints
│       │   ├── entity/          # JPA entities
│       │   ├── service/         # Business logic
│       │   │   └── impl/
│       │   ├── repository/      # Spring Data JPA
│       │   ├── dto/             # Request / Response DTOs
│       │   ├── exception/       # ErrorCode, GlobalExceptionHandler
│       │   └── filter/          # JWT filter, Rate limiting
│       └── resources/
│           ├── application.properties
│           ├── application-dev.properties          # (gitignored) — cấu hình thực
│           ├── application-dev.properties.example  # template
│           ├── firebase-service-account.json       # (gitignored)
│           └── db/migration/    # Flyway SQL scripts
├── flutter_app/
│   ├── pubspec.yaml
│   ├── .env.json                # (gitignored) — API keys
│   ├── .env.json.example        # template
│   ├── android/app/
│   │   └── google-services.json # (gitignored) — Firebase Android config
│   └── lib/
│       ├── main.dart
│       ├── firebase_options.dart
│       └── src/
│           ├── app.dart
│           ├── core/
│           │   ├── auth/        # AuthController, AuthRepository, FirebasePhoneService
│           │   ├── network/     # Dio provider, interceptors
│           │   ├── router/      # GoRouter, app_router.dart
│           │   ├── theme/       # AppTheme
│           │   └── fcm/         # FcmService (push notification)
│           └── features/
│               ├── auth/        # login, register, forgot/reset password
│               ├── home/        # HomeScreen, MainLayout (bottom nav)
│               ├── cars/        # CarListScreen, CarDetailScreen, CarTrackingScreen
│               ├── bookings/    # BookingCreate, BookingDetail, BookingHistory, PaymentWebview
│               ├── invoices/    # InvoiceList, InvoiceDetail
│               ├── notifications/ # NotificationScreen
│               ├── verification/  # eKYC flow
│               ├── owner/       # OwnerDashboard, OwnerCarList, OwnerCarForm, OwnerBookings
│               ├── admin/       # AdminDashboard, AdminUsers, AdminCars, AdminBookings
│               └── profile/     # ProfileScreen, ChangePasswordScreen
└── ekyc-service/
    ├── docker-compose.yml
    ├── main.py
    ├── face_service.py
    ├── liveness_service.py
    └── ocr_service.py
```

---

## Luồng Chính

```
[Đăng ký] ──► OTP SĐT ──► [Đăng nhập]
                                │
                         [eKYC] CCCD + Bằng lái + Selfie
                                │
                    [Tìm xe] ──► [Chọn ngày & địa điểm]
                                │
                          [Tạo đơn đặt] ──► [Thanh toán VNPay]
                                │                    │
                         [Thông báo FCM]      [Xác nhận tự động]
                                │
                   Owner: Duyệt / Từ chối
                                │
                    [Tracking GPS thời gian thực]
                                │
                    [Trả xe] ──► [Review] ──► [Hóa đơn]
```

---

## Yêu Cầu Cài Đặt

| Công cụ | Phiên bản | Windows | macOS | Linux |
|---------|-----------|---------|-------|-------|
| Java JDK | 21+ | [adoptium.net](https://adoptium.net) | `brew install temurin@21` | `apt install openjdk-21-jdk` |
| MySQL | 8+ | [mysql.com](https://dev.mysql.com/downloads) | `brew install mysql` | `apt install mysql-server` |
| Flutter | 3.11+ | [flutter.dev](https://flutter.dev/docs/get-started/install/windows) | `brew install flutter` | [flutter.dev/linux](https://flutter.dev/docs/get-started/install/linux) |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) | [developer.android.com](https://developer.android.com/studio) | [developer.android.com](https://developer.android.com/studio) |
| ngrok | Latest | [ngrok.com](https://ngrok.com/download) | `brew install ngrok` | `snap install ngrok` |

> **Chỉ cần ngrok nếu test trên thiết bị thật** (backend cần URL public để mobile kết nối).

---

## Hướng Dẫn Chạy

### 1. Clone & Chuẩn Bị DB

```bash
git clone <repo-url>
cd vehicle-booking-system
```

```sql
CREATE DATABASE vehicle_booking CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

---

### 2. Backend

**Bước 1 — Cấu hình**

```bash
cd backend/src/main/resources
# macOS / Linux
cp application-dev.properties.example application-dev.properties
# Windows
copy application-dev.properties.example application-dev.properties
```

Điền các giá trị vào `application-dev.properties`:

| Key | Lấy ở đâu |
|-----|-----------|
| `spring.datasource.password` | Mật khẩu MySQL local |
| `spring.mail.password` | [myaccount.google.com](https://myaccount.google.com) → Bảo mật → App Passwords |
| `cloudinary.cloud-name/api-key/api-secret` | [cloudinary.com](https://cloudinary.com) → Dashboard |
| `goong.api-key` | [account.goong.io](https://account.goong.io) |
| `vnpay.tmn-code` + `vnpay.hash-secret` | [sandbox.vnpayment.vn/devreg](https://sandbox.vnpayment.vn/devreg) |
| `viettelai.token` | [viettelai.vn](https://viettelai.vn) |

**Bước 2 — Firebase** *(tuỳ chọn — bỏ qua nếu dùng mock OTP)*

Đặt file `firebase-service-account.json` vào `backend/src/main/resources/`.  
Lấy tại: Firebase Console → Project Settings → Service Accounts → Generate new private key.

**Bước 3 — Chạy**

```bash
cd backend

# macOS / Linux
./gradlew bootRun --args='--spring.profiles.active=dev'

# Windows
gradlew.bat bootRun --args="--spring.profiles.active=dev"
```

Swagger UI: `http://localhost:8080/swagger-ui.html`

---

### 3. Flutter App

**Bước 1 — Cấu hình env**

```bash
cd flutter_app
# macOS / Linux
cp .env.json.example .env.json
# Windows
copy .env.json.example .env.json
```

Nội dung `.env.json`:

```json
{
  "BASE_URL": "https://xxxx.ngrok-free.app",
  "GOONG_MAP_KEY": "your_goong_map_key",
  "GOONG_API_KEY": "your_goong_api_key"
}
```

> Chạy `ngrok http 8080` rồi copy URL vào `BASE_URL`.

**Bước 2 — Firebase Android** *(tuỳ chọn — bỏ qua nếu dùng mock OTP)*

Đặt `google-services.json` vào `flutter_app/android/app/`.  
Lấy tại: Firebase Console → Project Settings → Android app → Download google-services.json.

**Bước 3 — Cài dependencies & chạy**

```bash
flutter pub get
flutter run --dart-define-from-file=.env.json
```

Chạy trên device cụ thể:
```bash
flutter devices   # xem danh sách
flutter run -d <device-id> --dart-define-from-file=.env.json
```

---

### 4. eKYC Service *(tuỳ chọn)*

Chỉ cần khi ViettelAI không khả dụng:

```bash
cd ekyc-service
docker-compose up -d
```

Service chạy tại `http://localhost:8001`. Đặt `ekyc.local-service-url=http://localhost:8001` trong `application-dev.properties`.

---

## File Cần Copy Thủ Công *(gitignored)*

Khi chuyển sang máy mới, copy 4 file sau (không có trong git):

| File | Mô tả |
|------|-------|
| `backend/src/main/resources/application-dev.properties` | Cấu hình backend (DB, API keys) |
| `backend/src/main/resources/firebase-service-account.json` | Firebase credentials |
| `flutter_app/.env.json` | API keys mobile |
| `flutter_app/android/app/google-services.json` | Firebase Android config |

---

## Tài Khoản Demo

| Role | Số điện thoại | Mật khẩu | OTP |
|------|--------------|----------|-----|
| ADMIN | `+84987654321` | `Password123!` | `123456` |
| OWNER | `+84901234567` | `Password123!` | `123456` |
| USER | `+84123456789` | `Password123!` | `123456` |

> OTP `123456` là mock mặc định (`twilio.mode=mock`).

---

## OTP Mode

Đặt `twilio.mode` trong `application-dev.properties`:

| Mode | Mô tả |
|------|-------|
| `mock` | OTP cố định = `123456`, không gửi SMS |
| `firebase` | Firebase Phone Auth — cần `firebase-service-account.json` + Phone Auth bật trên Firebase Console |
| `twilio` | Twilio Verify — cần `account-sid`, `auth-token`, `verify-service-sid` |

---

## Tài Liệu Thêm

| File | Nội dung |
|------|----------|
| [eKYC-SERVICE.md](eKYC-SERVICE.md) | Kiến trúc, API, cách chạy eKYC local service |
| [api-test-collection.json](api-test-collection.json) | Postman collection — 81 requests đầy đủ toàn bộ API |
| [docs/eKYC_AI_Plan.md](docs/eKYC_AI_Plan.md) | Kế hoạch tích hợp AI cho eKYC |

---

## Lưu Ý Quan Trọng

### Firebase Phone Auth (OTP SMS thật)

- Spark plan (miễn phí) giới hạn **10 SMS/ngày** và chặn một số region theo mặc định.
- Để test không tốn quota: Firebase Console → Authentication → Sign-in method → Phone → **Phone numbers for testing** → thêm số + OTP cố định.
- Cần thêm **SHA-1 fingerprint** của keystore vào Firebase Console (Android app) trước khi build:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

- Sau khi thêm SHA-1, tải lại `google-services.json` mới về.

### VNPay Sandbox

- URL thanh toán sandbox: `https://sandbox.vnpayment.vn/paymentv2/vpcpay.html`
- Thẻ test: [sandbox.vnpayment.vn/apis/docs/thanh-toan-pay](https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html)
- Mobile: Flutter WebView intercept URL `/api/payments/vnpay/return`, sau đó POST JSON tới `/api/payments/vnpay/confirm` — backend không cần reachable từ VNPay server.

### eKYC

- ViettelAI ưu tiên 1. Nếu không có token hoặc lỗi → tự fallback về local service (`localhost:8001`).
- Local service cần ~4GB RAM. Lần đầu chạy tải model ~500MB.
- Xem chi tiết: [eKYC-SERVICE.md](eKYC-SERVICE.md)

### Goong Maps

- Cần 2 key riêng: `GOONG_MAP_KEY` (tile/map display) và `GOONG_API_KEY` (geocoding/search API).
- Cả hai lấy tại [account.goong.io](https://account.goong.io).

### Multipart Upload

- Giới hạn: 10MB/file, 20MB/request (cấu hình trong `application.properties`).
- Ảnh xe lưu trên Cloudinary, URL trả về trong response.

### Ngrok

- Free plan chỉ cho 1 tunnel đồng thời. URL thay đổi mỗi lần restart.
- Sau khi restart ngrok, nhớ cập nhật `BASE_URL` trong `flutter_app/.env.json` và rebuild app.

---

## API Chính

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|-------|
| POST | `/api/auth/login` | — | Đăng nhập |
| POST | `/api/auth/register` | — | Đăng ký |
| GET | `/api/cars` | — | Danh sách xe |
| GET | `/api/cars/{id}` | — | Chi tiết xe |
| GET/POST | `/api/bookings` | USER | Lịch sử / Tạo đơn |
| POST | `/api/payments/vnpay/create` | USER | Tạo link thanh toán |
| POST | `/api/payments/vnpay/confirm` | — | Xác nhận thanh toán (mobile) |
| GET/POST | `/api/verification/**` | USER | eKYC |
| GET/PUT/DELETE | `/api/owner/**` | OWNER | Quản lý xe & đơn |
| GET | `/api/admin/**` | ADMIN | Quản trị hệ thống |
| GET | `/api/geo/**` | — | Geocoding / Reverse / Search |
| GET | `/api/notifications` | USER | Thông báo |
| PUT | `/api/user/fcm-token` | USER | Đăng ký FCM token |
