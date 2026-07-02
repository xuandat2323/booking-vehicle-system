package vehicle.booking.dto.request;

public record RegisterRequest(
        String name,
        String email,
        String password,
        String phone,
        String otp,
        String driveLicense,
        String role
) {
}
