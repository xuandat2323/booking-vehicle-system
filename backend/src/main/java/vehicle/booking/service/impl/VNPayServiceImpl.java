package vehicle.booking.service.impl;

import vehicle.booking.config.VNPayConfig;
import vehicle.booking.entity.Booking;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.service.VNPayService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;

/**
 * Triển khai dịch vụ tích hợp thanh toán VNPay.
 * Lớp này chịu trách nhiệm tạo URL thanh toán và xác minh tính toàn vẹn của dữ liệu trả về.
 * (Dùng để trình bày với hội đồng về việc tích hợp cổng thanh toán bên thứ 3)
 */
@Service
@RequiredArgsConstructor
public class VNPayServiceImpl implements VNPayService {

    private final VNPayConfig vnPayConfig;
    private final BookingRepository bookingRepository;

    /**
     * Tạo URL chuyển hướng người dùng đến cổng thanh toán VNPay Sandbox.
     * 
     * @param bookingId ID của đơn thuê xe cần thanh toán
     * @param request HttpServletRequest để lấy IP của người dùng (VNPay yêu cầu)
     * @return Chuỗi URL hoàn chỉnh chứa các tham số đã được băm (hash) bảo mật
     */
    @Override
    public String createPaymentUrl(Long bookingId, HttpServletRequest request) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        // Note: Booking total price is stored as BigDecimal, VNPay requires amount * 100
        long amount = booking.getTotalPrice().longValue() * 100;

        Map<String, String> vnp_Params = new HashMap<>();
        vnp_Params.put("vnp_Version", "2.1.0");
        vnp_Params.put("vnp_Command", "pay");
        vnp_Params.put("vnp_TmnCode", vnPayConfig.getVnpTmnCode());
        vnp_Params.put("vnp_Amount", String.valueOf(amount));
        vnp_Params.put("vnp_CurrCode", "VND");
        
        // Use mapping code if needed, default to VNPay's format
        vnp_Params.put("vnp_TxnRef", bookingId.toString() + "_" + System.currentTimeMillis());
        vnp_Params.put("vnp_OrderInfo", "Thanh toan don thue xe " + bookingId);
        vnp_Params.put("vnp_OrderType", "other");
        vnp_Params.put("vnp_Locale", "vn");

        vnp_Params.put("vnp_ReturnUrl", vnPayConfig.getVnpReturnUrl());
        vnp_Params.put("vnp_IpAddr", getIpAddress(request));

        Calendar cld = Calendar.getInstance(TimeZone.getTimeZone("Etc/GMT+7"));
        SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMddHHmmss");
        String vnp_CreateDate = formatter.format(cld.getTime());
        vnp_Params.put("vnp_CreateDate", vnp_CreateDate);
        
        cld.add(Calendar.MINUTE, 15);
        String vnp_ExpireDate = formatter.format(cld.getTime());
        vnp_Params.put("vnp_ExpireDate", vnp_ExpireDate);
        
        // Build query string
        List<String> fieldNames = new ArrayList<>(vnp_Params.keySet());
        Collections.sort(fieldNames);
        StringBuilder hashData = new StringBuilder();
        StringBuilder query = new StringBuilder();
        Iterator<String> itr = fieldNames.iterator();
        while (itr.hasNext()) {
            String fieldName = itr.next();
            String fieldValue = vnp_Params.get(fieldName);
            if ((fieldValue != null) && (fieldValue.length() > 0)) {
                //Build hash data
                hashData.append(fieldName);
                hashData.append('=');
                hashData.append(URLEncoder.encode(fieldValue, StandardCharsets.US_ASCII));
                //Build query
                query.append(URLEncoder.encode(fieldName, StandardCharsets.US_ASCII));
                query.append('=');
                query.append(URLEncoder.encode(fieldValue, StandardCharsets.US_ASCII));
                if (itr.hasNext()) {
                    query.append('&');
                    hashData.append('&');
                }
            }
        }
        
        String queryUrl = query.toString();
        String vnp_SecureHash = vnPayConfig.hashAllFields(vnp_Params);
        queryUrl += "&vnp_SecureHash=" + vnp_SecureHash;
        
        return vnPayConfig.getVnpPayUrl() + "?" + queryUrl;
    }

    /**
     * Xác minh chữ ký của VNPay khi có callback trả về.
     * Thuật toán: Lấy tất cả tham số (trừ vnp_SecureHash), sắp xếp theo bảng chữ cái,
     * nối lại và băm bằng HmacSHA512 với chuỗi secret key. Sau đó so sánh với mã hash VNPay gửi sang.
     * 
     * @param params Map chứa tất cả các tham số trả về từ VNPay
     * @return true nếu chữ ký hợp lệ (không bị giả mạo), ngược lại false
     */
    @Override
    public boolean verifyPayment(Map<String, String> params) {
        String vnp_SecureHash = params.get("vnp_SecureHash");
        if (vnp_SecureHash == null) {
            return false;
        }
        
        params.remove("vnp_SecureHashType");
        params.remove("vnp_SecureHash");
        
        String signValue = vnPayConfig.hashAllFields(params);
        return signValue.equals(vnp_SecureHash);
    }
    
    private String getIpAddress(HttpServletRequest request) {
        String ipAdress = request.getHeader("X-FORWARDED-FOR");
        if (ipAdress == null) {
            ipAdress = request.getRemoteAddr();
        }
        return ipAdress;
    }
}
