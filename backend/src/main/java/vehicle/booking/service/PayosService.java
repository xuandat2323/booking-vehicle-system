package vehicle.booking.service;

import vehicle.booking.dto.response.PayosPaymentResponse;

public interface PayosService {
    PayosPaymentResponse createPayment(Long bookingId);

    boolean handleWebhook(Object body);

    boolean simulatePaid(Long bookingId);

    boolean isPaid(Long bookingId);
}
