package vehicle.booking.controller;

import vehicle.booking.dto.request.ReviewRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.dto.response.ReviewResponse;
import vehicle.booking.service.ReviewService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/reviews")
@RequiredArgsConstructor
public class ReviewController {

    private final ReviewService reviewService;

    @PostMapping("/booking/{bookingId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<ReviewResponse>> createReview(
            @PathVariable Long bookingId,
            @Valid @RequestBody ReviewRequest request,
            Authentication authentication) {

        ReviewResponse response = reviewService.createReview(bookingId, request, authentication.getName());
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Đánh giá chuyến đi thành công", response)
        );
    }

    @GetMapping("/car/{carId}")
    public ResponseEntity<ApiResponse<PageResponse<ReviewResponse>>> getCarReviews(
            @PathVariable Long carId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 50));
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy danh sách đánh giá xe thành công",
                        reviewService.getCarReviews(carId, pageable))
        );
    }

    @GetMapping("/booking/{bookingId}")
    @PreAuthorize("hasAnyRole('USER', 'ADMIN')")
    public ResponseEntity<ApiResponse<ReviewResponse>> getBookingReview(@PathVariable Long bookingId) {
        ReviewResponse review = reviewService.getBookingReview(bookingId);
        // It's okay if review is null, it means no review yet.
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy đánh giá của chuyến đi thành công", review)
        );
    }
}
