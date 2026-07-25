package vehicle.booking.controller;

import vehicle.booking.config.SepayConfig;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.SepayPaymentResponse;
import vehicle.booking.service.SepayService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/payments/sepay")
@RequiredArgsConstructor
public class SepayPaymentController {

    private final SepayService sepayService;
    private final SepayConfig sepayConfig;

    @PostMapping("/create/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<SepayPaymentResponse>> create(@PathVariable Long bookingId) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Tạo QR SePay thành công", sepayService.createPayment(bookingId)));
    }

    @GetMapping("/status/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<Boolean>> status(@PathVariable Long bookingId) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Trạng thái thanh toán", sepayService.isPaid(bookingId)));
    }

    /**
     * Demo: xác nhận đã CK khi sepay.mode=mock (không cần tiền thật / webhook).
     */
    @PostMapping("/simulate/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<Boolean>> simulate(@PathVariable Long bookingId) {
        boolean ok = sepayService.simulatePaid(bookingId);
        return ResponseEntity.ok(new ApiResponse<>(ok, ok ? "Đã xác nhận đặt cọc (demo)" : "Thất bại", ok));
    }

    /**
     * Webhook SePay — public. Cấu hình URL: https://your-ngrok/api/payments/sepay/webhook
     * Response bắt buộc: {"success": true}
     */
    @PostMapping("/webhook")
    public Map<String, Object> webhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        if (StringUtils.hasText(sepayConfig.getWebhookApiKey())) {
            String expected = "Apikey " + sepayConfig.getWebhookApiKey();
            if (authorization == null || !authorization.equals(expected)) {
                return Map.of("success", false, "message", "Unauthorized");
            }
        }
        sepayService.handleWebhook(payload);
        return Map.of("success", true);
    }
}
