de# GoRento — Tài liệu phân tích nghiệp vụ và kế hoạch triển khai

## 1. Mục tiêu sản phẩm
GoRento là ứng dụng thuê xe di động theo định hướng mobile-first, xây dựng trên Flutter cho client và Spring Boot cho backend. Hệ thống cần hỗ trợ đầy đủ các luồng đặt xe, thanh toán, quản lý xe, tracking vị trí, và có khả năng tích hợp AI cho xác minh danh tính, chống gian lận, và hỗ trợ vận hành.

### Mục tiêu kinh doanh
- Tăng tỷ lệ chuyển đổi từ tìm xe sang đặt xe.
- Giảm thời gian xác minh người dùng.
- Giảm gian lận và tranh chấp booking.
- Nâng cao trải nghiệm đặt xe bằng map và tracking.
- Hỗ trợ vận hành cho admin/chủ xe.

### Mục tiêu kỹ thuật
- Backend tách lớp rõ ràng, dễ mở rộng.
- Mobile app có kiến trúc chuẩn, dễ phát triển tính năng sau này.
- Có nền tảng để tích hợp AI theo từng giai đoạn.

---

## 2. Nhóm người dùng và vai trò

### 2.1. Người thuê xe
- Đăng ký, đăng nhập, xác minh tài khoản.
- Tìm xe theo khu vực, loại xe, giá, số chỗ, thời gian.
- Chọn điểm đón/trả trên bản đồ.
- Đặt xe, thanh toán, theo dõi trạng thái booking.
- Xem lịch sử thuê xe, đánh giá, khiếu nại.

### 2.2. Chủ xe / nhân viên vận hành
- Quản lý xe, ảnh xe, vị trí xe, lịch trống.
- Cập nhật booking, bàn giao, hoàn tất, hủy.
- Quản lý đối soát thanh toán, invoice.
- Theo dõi review và phản hồi khiếu nại.

### 2.3. Admin hệ thống
- Quản lý người dùng, xe, booking, payment, invoice.
- Xem dashboard doanh thu và tình trạng xe.
- Xác minh người dùng, giám sát rủi ro, khóa tài khoản.

---

## 3. Phân tích chức năng cần có của GoRento

### 3.1. Luồng người dùng cơ bản
1. Đăng ký / đăng nhập.
2. Xác minh số điện thoại/email.
3. Tìm và lọc xe.
4. Xem chi tiết xe.
5. Chọn điểm đón/trả trên map.
6. Tạo booking.
7. Thanh toán.
8. Theo dõi booking và trạng thái xe.
9. Hoàn tất chuyến đi, review.

### 3.2. Luồng quản trị
1. Tạo và cập nhật xe.
2. Cập nhật vị trí và ảnh xe.
3. Xác nhận booking.
4. Theo dõi payment/invoice.
5. Xử lý hủy, hoàn tiền, tranh chấp.
6. Theo dõi báo cáo vận hành.

### 3.3. Luồng AI / trust & safety
1. Upload giấy tờ.
2. OCR và trích xuất thông tin.
3. Selfie/liveness detection.
4. Face match giữa selfie và giấy tờ.
5. Tính trust score.
6. Cảnh báo gian lận hoặc xác minh thất bại.

---

## 4. Đánh giá backend hiện tại

### 4.1. Phần đã có
Backend hiện tại đã có nền tảng khá tốt cho MVP:
- Done Auth với JWT và refresh token.
- Done Forgot/reset password.
- Done Car list, car detail, availability, ảnh xe.
- Done Booking create, booking history, booking cancel.
- Done Payment VNPay.
- Done Review APIs.
- Done Admin APIs cho dashboard, cars, bookings, users, payments, invoices.
- Done Security config, rate limit, scheduler, logging.

### 4.2. Phần đã bắt đầu bổ sung
- Done Tọa độ xe (`latitude`, `longitude`).
- Done Vị trí booking (pickup/dropoff).
- Done Tracking xe hiện tại và lịch sử tracking.

### 4.3. Phần còn thiếu
- Geocoding / reverse geocoding chuẩn.
- Nearby search theo lat/lng.
- Realtime tracking đúng nghĩa.
- Notification service.
- AI verification pipeline.
- Fraud detection / trust scoring.
- Event log / audit trail.
- Recommendation engine.
- Chuẩn hóa API contract toàn hệ thống.

---

## 5. Backend cần thiết kế thêm

### 5.1. Module đề xuất
- `auth`
- `user`
- `car`
- `booking`
- `payment`
- `invoice`
- `review`
- `tracking`
- `notification`
- `admin`
- `ai-verification`
- `analytics`

### 5.2. API bổ sung cho map và tracking
- `GET /api/maps/geocode`
- `GET /api/maps/reverse-geocode`
- `PUT /api/cars/{id}/location`
- `GET /api/cars/{id}/tracking`
- `GET /api/cars/{id}/tracking/history`
- `POST /api/bookings/{id}/pickup-location`
- `POST /api/bookings/{id}/dropoff-location`
- `GET /api/cars/nearby?lat=&lng=&radius=`

### 5.3. API bổ sung cho AI xác minh
- `POST /api/verification/documents`
- `POST /api/verification/selfie`
- `POST /api/verification/face-match`
- `GET /api/verification/status`
- `POST /api/verification/retry`

### 5.4. API bổ sung cho thông báo và vận hành
- `GET /api/notifications`
- `POST /api/notifications/read`
- `POST /api/admin/booking/events`
- `GET /api/admin/audit-logs`
- `GET /api/admin/risk-signals`

---

## 6. Kiến trúc backend đề xuất

### 6.1. MVP: Modular Monolith
Trong giai đoạn đầu, nên giữ Spring Boot theo hướng modular monolith:
- Dễ phát triển.
- Dễ bảo trì.
- Không quá phức tạp về triển khai.
- Phù hợp với team nhỏ hoặc giai đoạn product-market fit.

### 6.2. Khi nào tách microservice
Chỉ nên tách khi:
- AI verification có tải riêng.
- Tracking realtime cần scale riêng.
- Notification queue cần worker riêng.
- Analytics / recommendation tăng trưởng mạnh.

### 6.3. Phân lớp kỹ thuật
- Controller
- Service
- Repository
- DTO
- Entity
- Event / async processing
- External AI provider adapter

---

## 7. Plan phát triển backend

### Trạng thái roadmap backend
- Done Phase 1 — Chuẩn hóa nền tảng
- In progress Phase 2 — Map & Tracking
- Pending Phase 3 — AI verification
- Pending Phase 4 — Notification & Ops
- Pending Phase 5 — Intelligence

### Phase 1 — Chuẩn hóa nền tảng
Mục tiêu: đảm bảo backend sẵn sàng cho mobile app.

Deliverables:
- Done Chuẩn hóa response format.
- Done Chuẩn hóa validation request.
- Done Hoàn thiện migration DB.
- Done Bổ sung tọa độ cho car và booking.
- Done Bổ sung tracking location.
- Done Chuẩn hóa lỗi, error code, logging.

### Phase 2 — Map & Tracking
Mục tiêu: hỗ trợ map thực tế.

Deliverables:
- In progress Geocode/reverse geocode.
- Done Booking pickup/dropoff location.
- Done Car location update.
- Done Tracking history.
- Pending Nearby search.
- Pending Map data cho Flutter.

### Phase 3 — AI verification
Mục tiêu: xác minh người dùng và giảm gian lận.

Deliverables:
- Pending Upload giấy tờ.
- Pending OCR.
- Pending Selfie/liveness.
- Pending Face match.
- Pending Verification status.
- Pending Trust score.

### Phase 4 — Notification & Ops
Mục tiêu: tăng trải nghiệm và khả năng vận hành.

Deliverables:
- Pending Push notification.
- Pending Event log.
- Pending Audit trail.
- Pending Dashboard nâng cao.
- Pending Alert cho booking/payment/tracking.

### Phase 5 — Intelligence
Mục tiêu: cá nhân hóa và tối ưu doanh thu.

Deliverables:
- Pending Recommendation xe.
- Pending Fraud scoring.
- Pending Chatbot trợ lý.
- Pending Dự báo nhu cầu.

---

## 8. Plan cho app mobile Flutter

### Trạng thái roadmap mobile
- Done Sprint 1 — Auth flow, routing, token storage, guard route
- In progress Sprint 2 — Car list, car detail, booking foundation
- Pending Sprint 3 — Map chọn điểm đón/trả
- Pending Sprint 4 — Payment / invoice / tracking / notification
- Pending Sprint 5 — AI verification

### 8.1. Mục tiêu app mobile
- Đăng nhập và quản lý tài khoản.
- Tìm xe nhanh, đẹp, dễ dùng.
- Chọn điểm đón/trả bằng bản đồ.
- Đặt xe và thanh toán.
- Theo dõi booking và xe.
- Nhận thông báo trạng thái.
- Xác minh người dùng bằng AI.

### 8.2. Kiến trúc app Flutter đề xuất
- `feature-first` + `core`
- State management: Riverpod hoặc Bloc
- Routing: go_router
- Networking: dio
- Storage: flutter_secure_storage
- Map SDK: Google Maps hoặc Mapbox
- AI upload flow: camera/gallery + file upload

### 8.3. Cấu trúc màn hình đề xuất
#### Auth
- Splash
- Login
- Register
- Forgot password
- Reset password
- OTP verification

#### Người dùng
- Home
- Search cars
- Car detail
- Map chọn điểm đón/trả
- Booking create
- Booking detail
- Booking history
- Payment
- Invoice
- Profile
- Verification status

#### Tracking / map
- Car tracking screen
- Map route screen
- Pickup/dropoff confirmation screen

#### AI / trust
- Upload ID card
- Selfie capture
- Verification result
- Retry flow

### 8.4. Plan triển khai mobile
#### Sprint 1
- Done Hoàn thiện auth flow.
- Done Tổ chức cấu trúc dự án.
- Done Routing + token storage.
- Done Guard route.

#### Sprint 2
- In progress Car list / detail.
- Pending Search / filter.
- Pending Booking create.
- Pending Booking history.

#### Sprint 3
- Pending Map chọn điểm đón/trả.
- Pending Nearby search.
- Pending Gắn lat/lng vào booking.

#### Sprint 4
- Pending Payment / invoice.
- Pending Tracking xe.
- Pending Notification.

#### Sprint 5
- Pending AI verification.
- Pending Upload giấy tờ.
- Pending Selfie/liveness.
- Pending Kết nối backend verification.

---

## 9. Ưu tiên triển khai thực tế

### Ưu tiên 1
- Chuẩn hóa auth.
- Chuẩn hóa API response.
- Hoàn thiện car/booking/tracking location.

### Ưu tiên 2
- Làm Flutter auth + car browsing.
- Làm map chọn địa điểm.
- Làm booking flow.

### Ưu tiên 3
- Làm AI verification.
- Làm notification.
- Làm tracking realtime.

### Ưu tiên 4
- Làm recommendation và fraud detection.

---

## 10. Kết luận
GoRento hiện tại đã có nền tảng backend tốt cho booking, auth, payment và admin. Tuy nhiên để trở thành một ứng dụng thuê xe di động hiện đại, cần đầu tư thêm vào:
- location intelligence,
- tracking,
- map UX,
- AI verification,
- notification,
- và trust/safety.

Nếu triển khai theo roadmap ở trên, GoRento có thể đi từ MVP thuê xe cơ bản sang một nền tảng mobility có khả năng mở rộng dài hạn.
