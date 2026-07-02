package vehicle.booking.dto.response;

public record AuthenticationResponse(
        String token,
        String refreshToken,
        Long userId,
        String name,
        String phone,
        String role
) {
}
