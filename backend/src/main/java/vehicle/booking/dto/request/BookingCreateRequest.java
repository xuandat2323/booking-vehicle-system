package vehicle.booking.dto.request;

import java.math.BigDecimal;
import java.time.LocalDate;

public record BookingCreateRequest(
        Long carId,
        LocalDate startDate,
        LocalDate endDate,
        String pickupAddress,
        BigDecimal pickupLatitude,
        BigDecimal pickupLongitude,
        String dropoffAddress,
        BigDecimal dropoffLatitude,
        BigDecimal dropoffLongitude
) {
}