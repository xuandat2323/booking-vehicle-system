package vehicle.booking.service.impl;

import vehicle.booking.entity.Booking;
import vehicle.booking.entity.Car;
import vehicle.booking.entity.Payment;
import vehicle.booking.entity.User;
import vehicle.booking.entity.enums.PaymentStatus;
import vehicle.booking.service.EmailService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailServiceImpl implements EmailService {

    private final JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Override
    @Async
    public void sendOtpResetPassword(User user, String otp) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(fromEmail);
            message.setTo(user.getEmail());
            message.setSubject("[Vehicle Booking] Mã OTP đặt lại mật khẩu");
            message.setText(buildOtpEmailText(user.getName(), otp));

            mailSender.send(message);
            log.info("OTP email sent successfully to: {}", user.getEmail());

        } catch (Exception e) {
            log.error("Failed to send OTP email to {}: {}", user.getEmail(), e.getMessage(), e);
        }
    }

    @Override
    @Async
    public void sendPaymentConfirmation(Payment payment) {
        User user = payment.getInvoice().getBooking().getUser();
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(fromEmail);
            message.setTo(user.getEmail());

            boolean isSuccess = payment.getPaymentStatus() == PaymentStatus.SUCCESS;
            message.setSubject(isSuccess
                    ? "[Vehicle Booking] Xác nhận thanh toán thành công"
                    : "[Vehicle Booking] Thanh toán thất bại");
            message.setText(buildPaymentEmailText(payment));

            mailSender.send(message);
            log.info("Payment confirmation email sent to: {} | invoice: {} | status: {}",
                    user.getEmail(),
                    payment.getInvoice().getInvoiceNumber(),
                    payment.getPaymentStatus());

        } catch (Exception e) {
            log.error("Failed to send payment confirmation email to {}: {}", user.getEmail(), e.getMessage(), e);
        }
    }

    private String buildOtpEmailText(String userName, String otp) {
        return """
                Xin chào %s,

                Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản Vehicle Booking.

                Mã OTP của bạn là: %s

                Mã này có hiệu lực trong 1 phút.
                Vui lòng KHÔNG chia sẻ mã này với bất kỳ ai.

                Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.

                Trân trọng,
                Đội ngũ Vehicle Booking
                """.formatted(userName, otp);
    }

    private String buildPaymentEmailText(Payment payment) {
        Booking booking = payment.getInvoice().getBooking();
        Car car = booking.getCar();
        User user = booking.getUser();
        boolean isSuccess = payment.getPaymentStatus() == PaymentStatus.SUCCESS;

        String statusLabel = isSuccess ? "✅ THÀNH CÔNG" : "❌ THẤT BẠI";
        String bookingStatusNote = isSuccess
                ? "Đơn đặt xe của bạn đã được xác nhận hoàn tất."
                : "Đơn đặt xe của bạn đã bị huỷ do thanh toán thất bại. Xe đã được giải phóng.";

        return """
                Xin chào %s,

                Kết quả thanh toán: %s

                ── Chi tiết hoá đơn ──────────────────
                Mã hoá đơn   : %s
                Xe            : %s (%s)
                Biển số       : %s
                Thời gian thuê: %s → %s
                Số tiền       : %,.0f VNĐ
                Phương thức   : %s
                ─────────────────────────────────────

                %s

                Nếu bạn có thắc mắc, vui lòng liên hệ hỗ trợ.

                Trân trọng,
                Đội ngũ Vehicle Booking
                """.formatted(
                user.getName(),
                statusLabel,
                payment.getInvoice().getInvoiceNumber(),
                car.getBrand(), car.getModel(),
                car.getLicensePlate(),
                booking.getStartDate(), booking.getEndDate(),
                payment.getAmount(),
                payment.getPaymentMethod(),
                bookingStatusNote
        );
    }
}
