package vehicle.booking.dto.response;

import java.time.LocalDateTime;

public record UserSummaryResponse(
        Long userId,
        String name,
        String email,
        String phone,
        String driveLicense,
        String role,
        long totalBookings
) {}
