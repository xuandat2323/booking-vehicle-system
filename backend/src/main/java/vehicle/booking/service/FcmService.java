package vehicle.booking.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Sends FCM push notifications to a device FCM token.
 * Silently skips if Firebase is not initialized (e.g., no service account in dev).
 */
@Service
@Slf4j
public class FcmService {

    public void send(String fcmToken, String title, String body) {
        if (fcmToken == null || fcmToken.isBlank()) return;
        if (FirebaseApp.getApps().isEmpty()) {
            log.debug("FCM skipped — Firebase not initialized");
            return;
        }
        try {
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .build();
            String response = FirebaseMessaging.getInstance().send(message);
            log.debug("FCM sent: {}", response);
        } catch (Exception e) {
            log.warn("FCM send failed for token {}: {}", fcmToken.substring(0, Math.min(10, fcmToken.length())), e.getMessage());
        }
    }
}
