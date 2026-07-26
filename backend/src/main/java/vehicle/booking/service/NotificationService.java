package vehicle.booking.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vehicle.booking.dto.response.NotificationResponse;
import vehicle.booking.entity.Notification;
import vehicle.booking.entity.User;
import vehicle.booking.entity.enums.NotificationType;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.NotificationRepository;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.realtime.RealtimeEventHub;

import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final RealtimeEventHub realtimeEventHub;

    public void send(User user, String title, String message, NotificationType type, Long referenceId) {
        if (user == null) {
            return;
        }
        Notification n = new Notification();
        n.setUser(user);
        n.setTitle(title);
        n.setMessage(message);
        n.setType(type);
        n.setReferenceId(referenceId);
        notificationRepository.save(n);

        // Push to device if FCM token is registered
        fcmService.send(user.getFcmToken(), title, message);
        realtimeEventHub.publishNotificationCreated(user.getUserId(), n.getNotificationId());
    }

    /** Gửi thông báo tới toàn bộ tài khoản ADMIN đang hoạt động. */
    public void sendToAdmins(String title, String message, NotificationType type, Long referenceId) {
        List<User> admins = userRepository.findByRoleIgnoreCase("ADMIN");
        for (User admin : admins) {
            send(admin, title, message, type, referenceId);
        }
    }

    public Page<NotificationResponse> getMyNotifications(String phone, Pageable pageable) {
        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        return notificationRepository
                .findByUserUserIdOrderByCreatedAtDesc(user.getUserId(), pageable)
                .map(NotificationResponse::from);
    }

    public long countUnread(String phone) {
        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        return notificationRepository.countByUserUserIdAndIsReadFalse(user.getUserId());
    }

    @Transactional
    public void markAllRead(String phone) {
        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        notificationRepository.markAllReadByUserId(user.getUserId());
    }

    @Transactional
    public void markRead(Long notificationId, String phone) {
        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        notificationRepository.markReadById(notificationId, user.getUserId());
    }
}
