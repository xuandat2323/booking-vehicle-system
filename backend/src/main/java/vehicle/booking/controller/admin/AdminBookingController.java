package vehicle.booking.controller.admin;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.BookingResponse;
import vehicle.booking.dto.response.BookingSummaryResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.service.BookingService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/bookings")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminBookingController {

    private final BookingService bookingService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<BookingSummaryResponse>>> getAllBookings(
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "10") int size) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 50));

        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách tất cả booking thành công", PageResponse.of(bookingService.getAllBookings(pageable))));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<BookingResponse>> getBookingById(@PathVariable Long id) {
        BookingResponse response = bookingService.getBookingById(id, null, true);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy chi tiết booking thành công", response)
        );
    }

    @PutMapping("/{id}/confirm")
    public ResponseEntity<ApiResponse<BookingResponse>> confirmBooking(@PathVariable Long id) {
        BookingResponse response = bookingService.confirmBooking(id);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Xác nhận booking thành công", response)
        );
    }

    @PutMapping("/{id}/handover")
    public ResponseEntity<ApiResponse<BookingResponse>> handoverBooking(@PathVariable Long id) {
        BookingResponse response = bookingService.handoverBooking(id);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Bàn giao xe thành công", response)
        );
    }

    @PutMapping("/{id}/complete")
    public ResponseEntity<ApiResponse<BookingResponse>> completeBooking(@PathVariable Long id) {
        BookingResponse response = bookingService.completeBooking(id);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Hoàn thành booking thành công", response)
        );
    }

    @PutMapping("/{id}/return")
    public ResponseEntity<ApiResponse<BookingResponse>> returnBooking(@PathVariable Long id) {
        BookingResponse response = bookingService.returnBooking(id);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Nhận trả xe thành công", response)
        );
    }

    @PutMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<BookingResponse>> cancelBooking(@PathVariable Long id) {
        BookingResponse response = bookingService.cancelBooking(id, null, true);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Hủy booking thành công", response)
        );
    }
}