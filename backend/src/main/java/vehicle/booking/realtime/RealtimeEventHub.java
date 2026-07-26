package vehicle.booking.realtime;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Hub SSE in-memory: mỗi user/admin giữ kết nối dài để nhận sự kiện realtime.
 */
@Slf4j
@Service
public class RealtimeEventHub {

    private static final long SSE_TIMEOUT_MS = 0L; // không timeout; dùng heartbeat

    private final ConcurrentHashMap<Long, CopyOnWriteArrayList<SseEmitter>> userEmitters =
            new ConcurrentHashMap<>();
    private final CopyOnWriteArrayList<SseEmitter> adminEmitters = new CopyOnWriteArrayList<>();

    public SseEmitter subscribe(Long userId, boolean isAdmin) {
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT_MS);
        CopyOnWriteArrayList<SseEmitter> bucket =
                userEmitters.computeIfAbsent(userId, id -> new CopyOnWriteArrayList<>());
        bucket.add(emitter);
        if (isAdmin) {
            adminEmitters.add(emitter);
        }

        Runnable cleanup = () -> {
            bucket.remove(emitter);
            if (bucket.isEmpty()) {
                userEmitters.remove(userId, bucket);
            }
            adminEmitters.remove(emitter);
        };
        emitter.onCompletion(cleanup);
        emitter.onTimeout(cleanup);
        emitter.onError(ex -> cleanup.run());

        try {
            emitter.send(SseEmitter.event()
                    .name("connected")
                    .data(Map.of(
                            "userId", userId,
                            "admin", isAdmin
                    ), MediaType.APPLICATION_JSON));
        } catch (IOException e) {
            cleanup.run();
            emitter.completeWithError(e);
        }
        return emitter;
    }

    public void publishBookingUpdated(Long ownerUserId, Long bookingId, String status) {
        if (ownerUserId == null || bookingId == null) {
            return;
        }
        Map<String, Object> payload = Map.of(
                "type", "BOOKING_UPDATED",
                "bookingId", bookingId,
                "status", status == null ? "" : status,
                "userId", ownerUserId
        );
        afterCommit(() -> {
            sendToUser(ownerUserId, "booking", payload);
            sendToAdmins("booking", payload);
        });
    }

    public void publishNotificationCreated(Long userId, Long notificationId) {
        if (userId == null || notificationId == null) {
            return;
        }
        Map<String, Object> payload = Map.of(
                "type", "NOTIFICATION_CREATED",
                "notificationId", notificationId,
                "userId", userId
        );
        afterCommit(() -> sendToUser(userId, "notification", payload));
    }

    /**
     * Không phát SSE khi transaction chưa commit: client có thể refetch quá sớm
     * và nhận lại dữ liệu cũ. Ngoài transaction thì gửi ngay.
     */
    private void afterCommit(Runnable action) {
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

    @Scheduled(fixedRate = 20_000)
    public void heartbeat() {
        Map<String, Object> payload = Map.of("type", "HEARTBEAT");
        for (CopyOnWriteArrayList<SseEmitter> bucket : List.copyOf(userEmitters.values())) {
            for (SseEmitter emitter : bucket) {
                safeSend(emitter, "heartbeat", payload);
            }
        }
    }

    private void sendToUser(Long userId, String eventName, Map<String, Object> payload) {
        CopyOnWriteArrayList<SseEmitter> bucket = userEmitters.get(userId);
        if (bucket == null || bucket.isEmpty()) {
            return;
        }
        for (SseEmitter emitter : bucket) {
            safeSend(emitter, eventName, payload);
        }
    }

    private void sendToAdmins(String eventName, Map<String, Object> payload) {
        for (SseEmitter emitter : adminEmitters) {
            safeSend(emitter, eventName, payload);
        }
    }

    private void safeSend(SseEmitter emitter, String eventName, Map<String, Object> payload) {
        try {
            // Gửi Map + APPLICATION_JSON (không stringify trước) để Flutter parse 1 lần.
            emitter.send(SseEmitter.event()
                    .name(eventName)
                    .data(payload, MediaType.APPLICATION_JSON));
        } catch (Exception e) {
            try {
                emitter.completeWithError(e);
            } catch (Exception ignored) {
                // already completed
            }
            // cleanup via onError/onCompletion callbacks
            Iterator<Map.Entry<Long, CopyOnWriteArrayList<SseEmitter>>> it =
                    userEmitters.entrySet().iterator();
            while (it.hasNext()) {
                Map.Entry<Long, CopyOnWriteArrayList<SseEmitter>> entry = it.next();
                entry.getValue().remove(emitter);
                if (entry.getValue().isEmpty()) {
                    it.remove();
                }
            }
            adminEmitters.remove(emitter);
            log.debug("SSE client disconnected: {}", e.toString());
        }
    }
}
