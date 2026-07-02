package vehicle.booking.dto.response;

import java.time.LocalDateTime;

public record CarImageResponse(
        Long id,
        Long carId,
        String imageUrl,
        String publicId,
        String format,
        Long bytes,
        boolean isPrimary,
        int sortOrder,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
}
