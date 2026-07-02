package vehicle.booking.dto.response;

public record PhoneOtpSentResponse(
    String phone,
    long expiresInSeconds
) {
    
}
