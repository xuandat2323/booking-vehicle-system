package vehicle.booking.dto.request;

import vehicle.booking.entity.enums.PaymentMethod;

public record PaymentRequest(
        Long invoiceId,
        PaymentMethod paymentMethod
) {
}

