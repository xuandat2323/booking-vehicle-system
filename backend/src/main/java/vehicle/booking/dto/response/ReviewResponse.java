package vehicle.booking.dto.response;

import java.time.LocalDateTime;

public record ReviewResponse(
        Long reviewId,
        Long userId,
        String userName,
        Long carId,
        Long bookingId,
        Integer rating,
        String comment,
        LocalDateTime createdAt
) {}
