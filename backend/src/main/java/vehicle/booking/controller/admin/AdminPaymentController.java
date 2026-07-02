package vehicle.booking.controller.admin;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.dto.response.PaymentResponse;
import vehicle.booking.dto.response.PaymentSummaryResponse;
import vehicle.booking.entity.enums.PaymentStatus;
import vehicle.booking.service.PaymentService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/payments")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminPaymentController {
    private final PaymentService paymentService;
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<PaymentSummaryResponse>>> getAllPayments(
            @RequestParam(required = false)    PaymentStatus paymentStatus,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "10") int size) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 50));

        String message = paymentStatus != null
                ? "Lấy danh sách payment theo trạng thái " + paymentStatus + " thành công"
                : "Lấy danh sách tất cả payment thành công";

        return ResponseEntity.ok(new ApiResponse<>(
                true, message,
                PageResponse.of(paymentService.getAllPayments(paymentStatus, pageable))));
    }

    @PutMapping("/confirm/{invoiceId}")
    public ResponseEntity<ApiResponse<PaymentResponse>> confirmPayment(@PathVariable Long invoiceId, @RequestParam PaymentStatus result){
        PaymentResponse payment = paymentService.confirmPayment(invoiceId, result);
        String message = result == PaymentStatus.SUCCESS ? "Xác nhận thanh toán thành công" : "Xác nhận thanh toán thất bại";
        return ResponseEntity.ok(new ApiResponse<>(true, message, payment));
    }
}

