package vehicle.booking.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import vehicle.booking.dto.response.NotificationResponse;
import vehicle.booking.entity.User;
import vehicle.booking.entity.enums.NotificationType;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.NotificationRepository;
import vehicle.booking.repository.UserRepository;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final NotificationDispatchService notificationDispatchService;

    /**
     * Lên lịch gửi thông báo sau khi transaction commit — không chặn API booking.
     * FCM/network chạy async; lỗi gửi không làm hỏng nghiệp vụ chính.
     */
    public void send(User user, String title, String message, NotificationType type, Long referenceId) {
        if (user == null || user.getUserId() == null) {
            return;
        }
        Long userId = user.getUserId();
        NotificationType resolvedType = type != null ? type : NotificationType.SYSTEM;
        runAfterCommit(() ->
                notificationDispatchService.dispatch(userId, title, message, resolvedType, referenceId));
    }

    /** Gửi thông báo tới toàn bộ tài khoản ADMIN đang hoạt động. */
    public void sendToAdmins(String title, String message, NotificationType type, Long referenceId) {
        NotificationType resolvedType = type != null ? type : NotificationType.SYSTEM;
        runAfterCommit(() ->
                notificationDispatchService.dispatchToAdmins(title, message, resolvedType, referenceId));
    }

    /**
     * Chạy sau commit để tránh gửi thông báo khi booking rollback;
     * ngoài transaction thì chạy ngay (vẫn qua {@code @Async} dispatch).
     */
    private void runAfterCommit(Runnable action) {
        if (TransactionSynchronizationManager.isActualTransactionActive()
                && TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(
                    new TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            action.run();
                        }
                    }
            );
            return;
        }
        action.run();
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
