package vehicle.booking.service;

import vehicle.booking.dto.request.BookingCreateRequest;
import vehicle.booking.dto.response.BookingResponse;
import vehicle.booking.dto.response.BookingSummaryResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;

public interface BookingService {

    BookingResponse createBooking(BookingCreateRequest request, String currentUserPhone);

    Page<BookingSummaryResponse> getAllBookings(Pageable pageable);

    Page<BookingSummaryResponse> getMyBookings(String currentUserPhone, Pageable pageable);

    BookingResponse getBookingById(Long bookingId, String currentUserPhone, boolean isAdmin);

    BookingResponse cancelBooking(Long bookingId, String currentUserPhone, boolean isAdmin);

    BookingResponse updatePickupLocation(Long bookingId, String currentUserPhone, vehicle.booking.dto.request.BookingLocationRequest request);

    BookingResponse updateDropoffLocation(Long bookingId, String currentUserPhone, vehicle.booking.dto.request.BookingLocationRequest request);

    BookingResponse confirmBooking(Long bookingId);

    BookingResponse handoverBooking(Long bookingId);

    BookingResponse returnBooking(Long bookingId);

    BookingResponse returnBooking(Long bookingId, String currentUserPhone);

    BookingResponse completeBooking(Long bookingId);

    List<Long> expirePendingUnpaidBookings(LocalDateTime cutoff);
}
