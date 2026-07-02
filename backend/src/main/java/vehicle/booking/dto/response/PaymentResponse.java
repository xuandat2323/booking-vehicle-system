package vehicle.booking.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import vehicle.booking.entity.enums.PaymentMethod;
import vehicle.booking.entity.enums.PaymentStatus;

public record PaymentResponse(
        Long paymentId,
        Long invoiceId,
        String invoiceNumber,
        BigDecimal amount,
        PaymentMethod paymentMethod,
        PaymentStatus paymentStatus,
        String transactionCode,
        LocalDateTime createAt,
        LocalDateTime updateAt
) {
}

