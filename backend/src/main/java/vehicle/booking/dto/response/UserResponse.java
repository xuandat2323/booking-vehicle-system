package vehicle.booking.dto.response;

public record UserResponse(
        Long userId,
        String name,
        String email,
        String phone,
        String driveLicense,
        String role
) {
}
