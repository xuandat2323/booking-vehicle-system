package vehicle.booking.dto.response;

import vehicle.booking.entity.Notification;
import vehicle.booking.entity.enums.NotificationType;

import java.time.LocalDateTime;

public record NotificationResponse(
        Long id,
        String title,
        String message,
        NotificationType type,
        boolean isRead,
        Long referenceId,
        LocalDateTime createdAt
) {
    public static NotificationResponse from(Notification n) {
        return new NotificationResponse(
                n.getNotificationId(),
                n.getTitle(),
                n.getMessage(),
                n.getType(),
                n.isRead(),
                n.getReferenceId(),
                n.getCreatedAt()
        );
    }
}
