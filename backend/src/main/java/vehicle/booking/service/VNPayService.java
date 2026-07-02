package vehicle.booking.service;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;

public interface VNPayService {
    String createPaymentUrl(Long bookingId, HttpServletRequest request);
    boolean verifyPayment(Map<String, String> params);
}
