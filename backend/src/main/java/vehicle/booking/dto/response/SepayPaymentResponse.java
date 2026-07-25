package vehicle.booking.dto.response;

public record SepayPaymentResponse(
        Long bookingId,
        String paymentCode,
        long amount,
        String bankBin,
        String bankName,
        String accountNumber,
        String accountName,
        String transferContent,
        String qrImageUrl,
        boolean mockMode
) {}
