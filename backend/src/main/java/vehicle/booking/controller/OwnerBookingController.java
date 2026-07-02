package vehicle.booking.controller;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.BookingResponse;
import vehicle.booking.dto.response.BookingSummaryResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.User;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.service.BookingService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/owner/bookings")
@RequiredArgsConstructor
public class OwnerBookingController {

    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final BookingService bookingService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<BookingSummaryResponse>>> getBookingsForMyCars(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        User owner = userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        Page<Booking> bookings = bookingRepository.findByCarOwnerUserId(
                owner.getUserId(), PageRequest.of(page, Math.min(size, 50)));
        Page<BookingSummaryResponse> result = bookings.map(b -> new BookingSummaryResponse(
                b.getBookingId(),
                b.getCar().getName(),
                b.getCar().getBrand(),
                b.getCar().getLicensePlate(),
                b.getStartDate(),
                b.getEndDate(),
                b.getTotalPrice(),
                b.getStatus()
        ));
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách booking thành công", PageResponse.of(result)));
    }

    @PutMapping("/{bookingId}/confirm")
    public ResponseEntity<ApiResponse<BookingResponse>> confirmBooking(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal UserDetails userDetails) {
        verifyOwnerAccess(bookingId, userDetails.getUsername());
        BookingResponse response = bookingService.confirmBooking(bookingId);
        return ResponseEntity.ok(new ApiResponse<>(true, "Đã xác nhận đơn đặt xe", response));
    }

    @PutMapping("/{bookingId}/reject")
    public ResponseEntity<ApiResponse<BookingResponse>> rejectBooking(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal UserDetails userDetails) {
        verifyOwnerAccess(bookingId, userDetails.getUsername());
        BookingResponse response = bookingService.cancelBooking(bookingId, userDetails.getUsername(), true);
        return ResponseEntity.ok(new ApiResponse<>(true, "Đã từ chối đơn đặt xe", response));
    }

    private void verifyOwnerAccess(Long bookingId, String ownerPhone) {
        User owner = userRepository.findByPhone(ownerPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));
        if (booking.getCar().getOwner() == null
                || !booking.getCar().getOwner().getUserId().equals(owner.getUserId())) {
            throw new AppException(ErrorCode.BOOKING_OWNER_FORBIDDEN);
        }
    }
}
