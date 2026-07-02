package vehicle.booking.dto.request;

import java.math.BigDecimal;

public record BookingLocationRequest(
        String address,
        BigDecimal latitude,
        BigDecimal longitude
) {
}
