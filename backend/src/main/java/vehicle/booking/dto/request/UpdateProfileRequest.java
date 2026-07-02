package vehicle.booking.dto.request;

public record UpdateProfileRequest(
        String name,
        String email,
        String driveLicense
) {
}
