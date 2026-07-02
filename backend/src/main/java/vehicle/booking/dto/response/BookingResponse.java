package vehicle.booking.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import vehicle.booking.entity.enums.BookingStatus;

public record BookingResponse(
        Long bookingId,
        Long userId,
        Long invoiceId,
        String userName,
        String userPhone,
        Long carId,
        String carName,
        String carBrand,
        String carLicensePlate,
        LocalDate startDate,
        LocalDate endDate,
        BigDecimal totalPrice,
        BookingStatus status,
        LocalDateTime createdAt,
        LocalDateTime updatedAt,
        String pickupAddress,
        BigDecimal pickupLatitude,
        BigDecimal pickupLongitude,
        String dropoffAddress,
        BigDecimal dropoffLatitude,
        BigDecimal dropoffLongitude
) {
}
