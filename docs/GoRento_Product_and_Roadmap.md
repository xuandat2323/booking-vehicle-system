# GoRento — Product overview

## Vai trò

| Role | Quyền |
|------|--------|
| **USER** | Tìm xe theo chi nhánh, đặt xe, đặt cọc PayOS, hóa đơn, eKYC, chatbot |
| **ADMIN** | Dashboard, quản lý người dùng / xe (gán chi nhánh) / đơn |

Chỉ **USER** và **ADMIN**.

## Mô hình cửa hàng

- **3 chi nhánh** cố định: Hoàn Kiếm, Cầu Giấy, Thanh Xuân.  
- Mỗi xe thuộc một `branch_id`; địa chỉ xe = địa chỉ chi nhánh.  
- Khi book: điểm đón / trả chỉ chọn trong 3 chi nhánh (không free-map).

## Module chính

1. **Auth** — SĐT + password; OTP (mock / Firebase)  
2. **eKYC** — 5 bước (EasyOCR local) — xem `docs/eKYC.md`  
3. **Catalog** — xe theo chi nhánh, lọc, ảnh Cloudinary  
4. **Booking + PayOS** — đặt cọc VietQR / demo  
5. **Admin** — vận hành USER / xe / đơn  
6. **Chatbot** — gợi ý xe (USER)  

## Roadmap gợi ý

- [ ] Siết eKYC production (OCR + anti-spoof)  
- [ ] Firebase OTP production  
- [ ] PayOS live + IPN webhook ổn định  
- [ ] Báo cáo doanh thu theo chi nhánh  

Chi tiết chạy dự án: `README.md`.
