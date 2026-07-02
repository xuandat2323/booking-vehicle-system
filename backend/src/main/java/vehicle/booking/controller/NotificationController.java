package vehicle.booking.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.NotificationResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.service.NotificationService;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER')")
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<NotificationResponse>>> getMyNotifications(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication authentication) {
        return ResponseEntity.ok(new ApiResponse<>(
                true,
                "Lấy thông báo thành công",
                PageResponse.of(notificationService.getMyNotifications(authentication.getName(), PageRequest.of(page, Math.min(size, 50))))
        ));
    }

    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Long>> countUnread(Authentication authentication) {
        return ResponseEntity.ok(new ApiResponse<>(true, "OK", notificationService.countUnread(authentication.getName())));
    }

    @PutMapping("/read-all")
    public ResponseEntity<ApiResponse<Void>> markAllRead(Authentication authentication) {
        notificationService.markAllRead(authentication.getName());
        return ResponseEntity.ok(new ApiResponse<>(true, "Đã đánh dấu đọc tất cả", null));
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<ApiResponse<Void>> markRead(@PathVariable Long id, Authentication authentication) {
        notificationService.markRead(id, authentication.getName());
        return ResponseEntity.ok(new ApiResponse<>(true, "Đã đánh dấu đọc", null));
    }
}
