package vehicle.booking.service;

import vehicle.booking.dto.response.SepayPaymentResponse;

import java.util.Map;

public interface SepayService {
    SepayPaymentResponse createPayment(Long bookingId);

    /** SePay webhook — returns true if processed / already handled. */
    boolean handleWebhook(Map<String, Object> payload);

    /** Demo: đánh dấu đã thanh toán khi sepay.mode=mock */
    boolean simulatePaid(Long bookingId);

    boolean isPaid(Long bookingId);
}
