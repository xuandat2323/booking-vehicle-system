package vehicle.booking.service;

import vehicle.booking.entity.Payment;
import vehicle.booking.entity.User;

public interface EmailService {
    void sendOtpResetPassword(User user, String otp);
    void sendPaymentConfirmation(Payment payment);
}
