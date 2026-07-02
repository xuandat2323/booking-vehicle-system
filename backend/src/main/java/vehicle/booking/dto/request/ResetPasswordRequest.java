package vehicle.booking.dto.request;

public record ResetPasswordRequest(
        String email,
        String otp,
        String newPassword,
        String confirmPassword
) {
}
