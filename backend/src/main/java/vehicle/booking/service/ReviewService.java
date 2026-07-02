package vehicle.booking.service;

import vehicle.booking.dto.request.ReviewRequest;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.dto.response.ReviewResponse;
import org.springframework.data.domain.Pageable;

public interface ReviewService {
    ReviewResponse createReview(Long bookingId, ReviewRequest request, String currentUserPhone);
    
    PageResponse<ReviewResponse> getCarReviews(Long carId, Pageable pageable);
    
    ReviewResponse getBookingReview(Long bookingId);
}
