# Kế Hoạch Tối Ưu UI/UX cho GoRento

Tài liệu này đề xuất các cải tiến nhằm nâng cao trải nghiệm người dùng và tính thẩm mỹ của ứng dụng GoRento.

## 1. Phản Hồi Hệ Thống (Feedback System)
- **Vấn đề:** Hiện tại ứng dụng thiếu các thông báo phản hồi khi thao tác thành công hoặc thất bại, hoặc chỉ sử dụng SnackBar mặc định đơn điệu.
- **Giải pháp:**
    - Triển khai bộ Toast/SnackBar tùy chỉnh với các trạng thái: **Thành công (Success)**, **Lỗi (Error)**, **Cảnh báo (Warning)**, và **Thông tin (Info)**.
    - Sử dụng các icon và màu sắc đặc trưng của brand để tăng tính nhận diện.
    - Thêm các trạng thái Loading (Skeleton screens hoặc Shimmer effect) khi đang tải dữ liệu thay vì chỉ dùng vòng quay đơn giản.

## 2. Luồng Đăng Nhập & Đăng Ký (Auth Flow)
- **Vấn đề:** Thông báo lỗi hiện tại đang hiển thị raw error message (như "DioException..."), gây khó hiểu cho người dùng.
- **Giải pháp:**
    - Mapping mã lỗi từ Backend thành thông điệp tiếng Việt thân thiện (ví dụ: "Sai số điện thoại hoặc mật khẩu" thay vì "401 Unauthorized").
    - Thêm tính năng "Ghi nhớ đăng nhập" và đăng nhập bằng sinh trắc học (Vân tay/FaceID).
    - Cải thiện UX phần nhập OTP: Tự động điền (Auto-fill) và đếm ngược thời gian gửi lại.

## 3. Giao Diện Người Dùng (Visual Design)
- **Vấn đề:** Cần đồng bộ hóa hệ thống thiết kế (Design System).
- **Giải pháp:**
    - **Typography:** Sử dụng font 'Inter' một cách nhất quán (đã có trong code nhưng cần tối ưu size/weight).
    - **Micro-interactions:** Thêm các hiệu ứng chuyển cảnh mượt mà giữa các màn hình và các hiệu ứng feedback khi chạm (ripple effect, scale animation).
    - **Dark Mode:** Hỗ trợ chế độ tối để giảm mỏi mắt và tiết kiệm pin.
    - **Empty States:** Thiết kế các màn hình "Trống" (không có xe, không có đơn đặt) sinh động với hình minh họa (illustrations).

## 4. Trải Nghiệm Đặt Xe (Booking Experience)
- **Vấn đề:** Việc chọn ngày và vị trí cần trực quan hơn.
- **Giải pháp:**
    - Tích hợp bộ chọn ngày (Date Range Picker) tùy chỉnh theo style của app.
    - Cải thiện bản đồ (Goong Maps): Thêm các marker xe sinh động, hiển thị quãng đường và thời gian dự kiến.
    - Hiển thị rõ ràng các chi phí phát sinh (phí bảo hiểm, phí giao xe) ngay từ bước đầu.

## 5. Quản Lý Xe (Owner Dashboard)
- **Giải pháp:**
    - Biểu đồ thống kê doanh thu trực quan.
    - Quy trình đăng xe (Add Car) theo từng bước (Stepper) để người dùng không bị ngợp thông tin.

---

## Các Bước Thực Hiện Tiếp Theo
1. [ ] Triển khai `ToastUtils` và áp dụng cho màn hình Login/Register.
2. [ ] Xây dựng hệ thống Error Mapping cho toàn bộ ứng dụng.
3. [ ] Thêm hiệu ứng Shimmer cho danh sách xe.
4. [ ] Tối ưu hóa bộ chọn địa chỉ trên bản đồ.
