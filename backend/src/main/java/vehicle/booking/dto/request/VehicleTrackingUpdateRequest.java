package vehicle.booking.dto.request;

import java.math.BigDecimal;

public record VehicleTrackingUpdateRequest(
        BigDecimal latitude,
        BigDecimal longitude,
        BigDecimal speedKmh,
        Integer heading,
        String address,
        String source
) {
}
