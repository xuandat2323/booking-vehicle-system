package vehicle.booking.controller;

import vehicle.booking.dto.request.BookingCreateRequest;
import vehicle.booking.dto.request.BookingLocationRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.BookingResponse;
import vehicle.booking.dto.response.BookingSummaryResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.service.BookingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/bookings")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER')")
public class BookingController {

    private final BookingService bookingService;

    @PostMapping
    public ResponseEntity<ApiResponse<BookingResponse>> createBooking(
            @RequestBody @Valid BookingCreateRequest request,
            Authentication authentication) {

        String currentUserPhone = authentication.getName();

        BookingResponse response = bookingService.createBooking(request, currentUserPhone);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(true, "Tạo booking thành công", response));
    }

    @GetMapping("/my-bookings")
    public ResponseEntity<ApiResponse<PageResponse<BookingSummaryResponse>>> getMyBookings(
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "10") int size,
            Authentication authentication) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 50));

        return ResponseEntity.ok(new ApiResponse<>(
                true,
                "Lấy danh sách booking của bạn thành công",
                PageResponse.of(bookingService.getMyBookings(authentication.getName(), pageable))));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<BookingResponse>> getBookingById(
            @PathVariable Long id,
            Authentication authentication) {

        String currentUserPhone = authentication.getName();
        boolean isAdmin = false;

        BookingResponse response = bookingService.getBookingById(id, currentUserPhone, isAdmin);

        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy chi tiết booking thành công", response)
        );
    }

    @PutMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<BookingResponse>> cancelMyBooking(
            @PathVariable Long id,
            Authentication authentication) {
        String currentUserPhone = authentication.getName();
        boolean isAdmin = false;

        BookingResponse response = bookingService.cancelBooking(id, currentUserPhone, isAdmin);

        return ResponseEntity.ok(
                new ApiResponse<>(true, "Huỷ booking thành công", response)
        );
    }

    @PutMapping("/{id}/pickup-location")
    public ResponseEntity<ApiResponse<BookingResponse>> updatePickupLocation(
            @PathVariable Long id,
            @RequestBody BookingLocationRequest request,
            Authentication authentication) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Cap nhat diem don thanh cong", bookingService.updatePickupLocation(id, authentication.getName(), request)));
    }

    @PutMapping("/{id}/dropoff-location")
    public ResponseEntity<ApiResponse<BookingResponse>> updateDropoffLocation(
            @PathVariable Long id,
            @RequestBody BookingLocationRequest request,
            Authentication authentication) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Cap nhat diem tra thanh cong", bookingService.updateDropoffLocation(id, authentication.getName(), request)));
    }
}