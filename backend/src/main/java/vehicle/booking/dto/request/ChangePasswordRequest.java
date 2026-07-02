package vehicle.booking.dto.request;

public record ChangePasswordRequest(
        String oldPassword,
        String newPassword,
        String confirmPassword
) {
}
