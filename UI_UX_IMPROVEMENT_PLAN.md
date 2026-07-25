# Kế Hoạch Tối Ưu UI/UX Chi Tiết cho GoRento

Tài liệu này đánh giá hiện trạng và đề xuất các bước cụ thể để nâng cấp trải nghiệm người dùng (UX) và giao diện (UI) cho ứng dụng GoRento.

## 1. Đánh Giá Hiện Trạng

| Màn hình | Ưu điểm | Hạn chế |
|----------|---------|---------|
| **Đăng nhập** | Layout rõ ràng, Hero header đẹp. | Lỗi hiển thị thô (DioException), thiếu feedback khi thành công. |
| **Trang chủ** | Có thống kê nhanh, quick actions. | Các card còn đơn điệu, thiếu hiệu ứng loading (Shimmer). |
| **Danh sách xe** | Đầy đủ thông tin, có tìm kiếm gần đây. | Bộ lọc dùng ExpansionTile chiếm nhiều diện tích, hình ảnh xe tải chậm. |
| **Hệ thống** | Đã có Design System cơ bản. | Màu sắc chưa thực sự nổi bật, thiếu Micro-interactions. |

---

## 2. Kế Hoạch Tối Ưu Chi Tiết

### A. Hệ Thống Design & Phản Hồi (System Wide)
- [x] **Hệ thống Toast:** Thay thế SnackBar mặc định bằng `ToastUtils` (Success, Error, Warning).
- [ ] **Shimmer Loading:** Thay thế `CircularProgressIndicator` bằng Shimmer effect cho Card xe và Stats để tạo cảm giác ứng dụng phản hồi nhanh hơn.
- [ ] **Vibrant Palette:** Tinh chỉnh bảng màu `AppTheme` để các màu Primary/Secondary tương phản tốt hơn trên nền Surface.
- [ ] **Micro-animations:** Sử dụng `AnimatedContainer` hoặc `hero` tag cho ảnh xe khi chuyển từ danh sách vào chi tiết.

### B. Màn Hình Đăng Nhập & Đăng Ký (Auth)
- [x] **Friendly Errors:** Mapping lỗi từ API/Network sang tiếng Việt dễ hiểu.
- [ ] **Input Focus:** Tự động focus vào ô mật khẩu sau khi nhập xong số điện thoại.
- [ ] **Social Auth:** Thêm UI placeholders cho Google/Apple login (nếu có trong lộ trình).

### C. Màn Hình Trang Chủ (Home)
- [ ] **Personalization:** Hiển thị tên người dùng và ảnh đại diện rõ nét hơn ở Header.
- [ ] **Vibrant Stats:** Sử dụng Gradient nhẹ cho các thẻ thống kê (Đơn thuê, Trạng thái).
- [ ] **Banner Khuyến Mãi:** Thêm Carousel các chương trình ưu đãi hoặc xe mới nổi bật.

### D. Màn Hình Danh Sách Xe (Car List)
- [ ] **Filter Bottom Sheet:** Chuyển bộ lọc nâng cao từ `ExpansionTile` sang `ModalBottomSheet` để tối ưu không gian hiển thị danh sách.
- [ ] **Quick Filter Chips:** Thêm các chip lọc nhanh (Giá thấp nhất, Gần tôi, 7 chỗ) ngay dưới Search bar.
- [ ] **Image Optimization:** Sử dụng `CachedNetworkImage` để lưu đệm ảnh xe, tránh nháy khi cuộn.
- [ ] **Empty State:** Thiết kế màn hình "Không tìm thấy xe phù hợp" với nút "Xóa bộ lọc".

### E. Quy Trình Đặt Xe & Thanh Toán (Booking)
- [ ] **Stepper UI:** Chia quy trình đặt xe thành 3 bước: Chọn ngày/vị trí -> Kiểm tra thông tin -> Thanh toán.
- [ ] **Price Summary:** Hiển thị bảng chi tiết giá (Giá thuê x số ngày + phí) một cách minh bạch trước khi bấm đặt.

### F. Kỹ Thuật & Khả Dụng (Technical UX)
- [x] **Connection Diagnostics:** Thêm bộ kiểm tra kết nối (Connection Status Chip) tại màn hình đăng nhập để chẩn đoán lỗi 502 Bad Gateway hoặc Timeout ngay lập tức.
- [ ] **Offline Handling:** Hiển thị thông báo và cho phép xem lại dữ liệu đã cache khi mất kết nối mạng.
- [x] **Request Retry:** Tự động thử lại request khi gặp lỗi mạng tạm thời (đã tích hợp trong Dio interceptor cho refresh token).

---

## 3. Lộ Trình Thực Hiện (Priority)

1. **Ưu tiên 1 (Ngay lập tức):** Hoàn thiện `ToastUtils` và Shimmer loading (Cải thiện cảm nhận về tốc độ).
2. **Ưu tiên 2 (Giao diện):** Refactor bộ lọc danh sách xe sang Bottom Sheet và tối ưu màu sắc Theme.
3. **Ưu tiên 3 (Nâng cao):** Thêm animations và tối ưu hóa bộ nhớ (Caching ảnh).

---
*Cập nhật lần cuối: 24/05/2024*
