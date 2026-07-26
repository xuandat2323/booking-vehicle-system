package vehicle.booking.dto.response;

public record EmailOtpSentResponse(
        String email,
        long expiresInSeconds
) {
}
