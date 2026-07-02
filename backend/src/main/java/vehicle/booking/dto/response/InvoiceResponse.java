package vehicle.booking.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import vehicle.booking.entity.enums.InvoiceStatus;

public record InvoiceResponse(
        Long invoiceId,
        String invoiceNumber,
        Long bookingId,
        Long userId,
        String userName,
        String userPhone,
        Long carId,
        String carName,
        String carBrand,
        String carLicensePlate,
        LocalDate startDate,
        LocalDate endDate,
        BigDecimal totalAmount,
        InvoiceStatus status,
        String paymentMethod,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
}

