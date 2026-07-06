package vehicle.booking.controller;

import vehicle.booking.config.VNPayConfig;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.service.VNPayService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/payments/vnpay")
@RequiredArgsConstructor
public class PaymentController {

    private final VNPayService vnPayService;
    private final BookingRepository bookingRepository;
    private final VNPayConfig vnPayConfig;

    @PostMapping("/create/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<String>> createPaymentUrl(@PathVariable Long bookingId, HttpServletRequest request) {
        String paymentUrl = vnPayService.createPaymentUrl(bookingId, request);
        return ResponseEntity.ok(new ApiResponse<>(true, "Tạo URL thanh toán thành công", paymentUrl));
    }

    /**
     * Mobile endpoint — called by Flutter webview after intercepting VNPay return URL.
     * Accepts the raw VNPay query params as a JSON body, verifies signature,
     * updates booking status, and returns JSON (no HTTP redirect).
     */
    @PostMapping("/confirm")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<Boolean>> confirmPayment(@RequestBody Map<String, String> params) {
        Map<String, String> mutableParams = new HashMap<>(params);
        if (!vnPayService.verifyPayment(mutableParams)) {
            return ResponseEntity.ok(new ApiResponse<>(false, "Chữ ký không hợp lệ", false));
        }

        String responseCode = params.get("vnp_ResponseCode");
        String txnRef = params.get("vnp_TxnRef");
        if (txnRef == null) {
            return ResponseEntity.ok(new ApiResponse<>(false, "Thiếu mã giao dịch", false));
        }

        Long bookingId = Long.parseLong(txnRef.split("_")[0]);

        if ("00".equals(responseCode)) {
            Booking booking = bookingRepository.findById(bookingId).orElse(null);
            if (booking != null && booking.getStatus() == BookingStatus.PENDING) {
                booking.setStatus(BookingStatus.DEPOSIT_PAID);
                bookingRepository.save(booking);
            }
            return ResponseEntity.ok(new ApiResponse<>(true, "Thanh toán thành công", true));
        }

        return ResponseEntity.ok(new ApiResponse<>(false, "Thanh toán thất bại (mã: " + responseCode + ")", false));
    }

    /** Web return — kept for browser / web frontend compatibility. */
    @GetMapping("/return")
    public void paymentReturn(@RequestParam Map<String, String> params, HttpServletResponse response) throws IOException {
        String frontendRedirectUrl = vnPayConfig.getVnpFrontendUrl();

        Map<String, String> mutableParams = new HashMap<>(params);
        if (vnPayService.verifyPayment(mutableParams)) {
            String vnp_ResponseCode = params.get("vnp_ResponseCode");
            String vnp_TxnRef = params.get("vnp_TxnRef");

            Long bookingId = Long.parseLong(vnp_TxnRef.split("_")[0]);

            if ("00".equals(vnp_ResponseCode)) {
                Booking booking = bookingRepository.findById(bookingId).orElse(null);
                if (booking != null && booking.getStatus() == BookingStatus.PENDING) {
                    booking.setStatus(BookingStatus.DEPOSIT_PAID);
                    bookingRepository.save(booking);
                }
                response.sendRedirect(frontendRedirectUrl + "?payment=success");
                return;
            }
            response.sendRedirect(frontendRedirectUrl + "?payment=failed");
            return;
        }

        response.sendRedirect(frontendRedirectUrl + "?payment=error");
    }
}
