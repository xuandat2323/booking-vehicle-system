package vehicle.booking.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import vehicle.booking.entity.enums.InvoiceStatus;

public record InvoiceSummaryResponse(
        Long invoiceId,
        String invoiceNumber,
        String carName,
        String carLicensePlate,
        LocalDate startDate,
        LocalDate endDate,
        BigDecimal totalAmount,
        InvoiceStatus invoiceStatus,
        LocalDateTime createAt
) {
}

