package vehicle.booking.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record VehicleTrackingResponse(
        Long carId,
        BigDecimal latitude,
        BigDecimal longitude,
        BigDecimal speedKmh,
        Integer heading,
        String address,
        String source,
        LocalDateTime updatedAt
) {
}
