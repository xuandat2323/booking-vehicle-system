package vehicle.booking.dto.response;

public record PayosPaymentResponse(
        Long bookingId,
        Long orderCode,
        long amount,
        String checkoutUrl,
        String qrCode,
        String qrImageUrl,
        String paymentLinkId,
        String bankBin,
        String accountNumber,
        String accountName,
        String description,
        String paymentContent,
        String carName,
        String renterName,
        String rentalPeriod,
        boolean mockMode
) {}
