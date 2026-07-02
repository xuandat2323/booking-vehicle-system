package vehicle.booking.service.impl;

import vehicle.booking.dto.request.ReviewRequest;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.dto.response.ReviewResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.Review;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.repository.ReviewRepository;
import vehicle.booking.service.ReviewService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Triển khai dịch vụ Quản lý Đánh giá (Reviews).
 * Xử lý logic: Cho phép người dùng đánh giá xe sau khi hoàn thành chuyến đi.
 * Ràng buộc: Mỗi đơn đặt xe chỉ được đánh giá 1 lần, người đánh giá phải là chủ đơn.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReviewServiceImpl implements ReviewService {

    private final ReviewRepository reviewRepository;
    private final BookingRepository bookingRepository;

    /**
     * Tạo đánh giá mới cho một đơn đặt xe.
     * Kiểm tra: Đơn tồn tại, thuộc quyền sở hữu của User, trạng thái là COMPLETED, chưa được đánh giá trước đó.
     */
    @Override
    @Transactional
    public ReviewResponse createReview(Long bookingId, ReviewRequest request, String currentUserPhone) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (!booking.getUser().getPhone().equals(currentUserPhone)) {
            throw new AppException(ErrorCode.BOOKING_ACCESS_DENIED);
        }

        if (booking.getStatus() != BookingStatus.COMPLETED) {
            throw new AppException(ErrorCode.REVIEW_BOOKING_NOT_COMPLETED);
        }

        if (reviewRepository.existsByBookingBookingId(bookingId)) {
            throw new AppException(ErrorCode.REVIEW_ALREADY_EXISTS);
        }

        Review review = new Review();
        review.setUser(booking.getUser());
        review.setCar(booking.getCar());
        review.setBooking(booking);
        review.setRating(request.rating());
        review.setComment(request.comment());

        review = reviewRepository.save(review);
        return mapToResponse(review);
    }

    @Override
    public PageResponse<ReviewResponse> getCarReviews(Long carId, Pageable pageable) {
        Page<Review> reviews = reviewRepository.findByCarCarIdOrderByCreatedAtDesc(carId, pageable);
        return PageResponse.of(reviews.map(this::mapToResponse));
    }

    @Override
    public ReviewResponse getBookingReview(Long bookingId) {
        Review review = reviewRepository.findByBookingBookingId(bookingId);
        return review != null ? mapToResponse(review) : null;
    }
    
    private ReviewResponse mapToResponse(Review review) {
        return new ReviewResponse(
                review.getReviewId(),
                review.getUser().getUserId(),
                review.getUser().getName(),
                review.getCar().getCarId(),
                review.getBooking().getBookingId(),
                review.getRating(),
                review.getComment(),
                review.getCreatedAt()
        );
    }
}
