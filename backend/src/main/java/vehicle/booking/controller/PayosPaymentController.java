package vehicle.booking.controller;

import vehicle.booking.config.PayosConfig;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.PayosPaymentResponse;
import vehicle.booking.service.PayosService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/payments/payos")
@RequiredArgsConstructor
public class PayosPaymentController {

    private final PayosService payosService;
    private final PayosConfig payosConfig;

    @PostMapping("/create/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<PayosPaymentResponse>> create(@PathVariable Long bookingId) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Tạo thanh toán PayOS thành công",
                payosService.createPayment(bookingId)));
    }

    @GetMapping("/status/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<Boolean>> status(@PathVariable Long bookingId) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Trạng thái thanh toán",
                payosService.isPaid(bookingId)));
    }

    @PostMapping("/simulate/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<Boolean>> simulate(@PathVariable Long bookingId) {
        boolean ok = payosService.simulatePaid(bookingId);
        return ResponseEntity.ok(new ApiResponse<>(ok, ok ? "Đã xác nhận đặt cọc (demo)" : "Thất bại", ok));
    }

    /**
     * Webhook PayOS — public. Đăng ký: https://&lt;host&gt;/api/payments/payos/webhook
     */
    @PostMapping("/webhook")
    public Map<String, Object> webhook(@RequestBody(required = false) Object body) {
        try {
            payosService.handleWebhook(body != null ? body : Map.of());
            return Map.of("success", true);
        } catch (Exception e) {
            String msg = e.getMessage() == null ? "error" : e.getMessage();
            return Map.of("success", false, "message", msg);
        }
    }

    @GetMapping("/return")
    public void paymentReturn(HttpServletResponse response) throws IOException {
        response.sendRedirect(appendQuery(payosConfig.getFrontendUrl(), "payment=success"));
    }

    @GetMapping("/cancel")
    public void paymentCancel(HttpServletResponse response) throws IOException {
        response.sendRedirect(appendQuery(payosConfig.getFrontendUrl(), "payment=cancel"));
    }

    private static String appendQuery(String base, String query) {
        if (base == null || base.isBlank()) return "/?" + query;
        if (base.contains("?")) {
            return base + "&" + query;
        }
        // Hash routes: http://host/#/bookings → http://host/#/bookings?payment=success
        int hash = base.indexOf('#');
        if (hash >= 0) {
            String before = base.substring(0, hash);
            String after = base.substring(hash);
            if (after.contains("?")) {
                return before + after + "&" + query;
            }
            return before + after + "?" + query;
        }
        return base + "?" + query;
    }
}
