package vehicle.booking.dto.request;

import java.math.BigDecimal;

public record CarLocationUpdateRequest(
        BigDecimal latitude,
        BigDecimal longitude,
        String address,
        String source
) {
}
