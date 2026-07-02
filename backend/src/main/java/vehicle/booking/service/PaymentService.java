package vehicle.booking.service;

import vehicle.booking.dto.request.PaymentRequest;
import vehicle.booking.dto.response.PaymentResponse;
import vehicle.booking.dto.response.PaymentSummaryResponse;
import vehicle.booking.entity.enums.PaymentStatus;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface PaymentService {
    Page<PaymentSummaryResponse> getMyPayments(String currentUserPhone, Pageable pageable);
    PaymentResponse getPaymentById(Long paymentId, String currentUserPhone, boolean isAdmin);
    PaymentResponse confirmPayment(Long invoiceId, PaymentStatus result);
    Page<PaymentSummaryResponse> getAllPayments(PaymentStatus paymentStatus, Pageable pageable);
}

