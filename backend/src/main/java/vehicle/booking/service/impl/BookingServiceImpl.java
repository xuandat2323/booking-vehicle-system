package vehicle.booking.service.impl;

import vehicle.booking.dto.request.BookingCreateRequest;
import vehicle.booking.dto.request.BookingLocationRequest;
import vehicle.booking.dto.response.BookingResponse;
import vehicle.booking.dto.response.BookingSummaryResponse;
import vehicle.booking.entity.*;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.InvoiceStatus;
import vehicle.booking.exception.*;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.repository.CarRepository;
import vehicle.booking.repository.InvoiceRepository;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.entity.enums.NotificationType;
import vehicle.booking.service.BookingService;
import vehicle.booking.service.InvoiceService;
import vehicle.booking.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Triển khai nghiệp vụ chính: Đặt xe (Booking).
 * Chịu trách nhiệm:
 * 1. Kiểm tra tính khả dụng của xe (trùng lịch).
 * 2. Tính toán tổng tiền theo ngày thuê.
 * 3. Quản lý vòng đời đơn hàng: PENDING -> CONFIRMED -> IN_PROGRESS -> COMPLETED.
 * 4. Tự động hủy đơn quá hạn thanh toán.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BookingServiceImpl implements BookingService {

    private final BookingRepository bookingRepository;
    private final CarRepository carRepository;
    private final InvoiceRepository invoiceRepository;
    private final UserRepository userRepository;
    private final InvoiceService invoiceService;
    private final NotificationService notificationService;

    /**
     * Tạo đơn đặt xe mới.
     * Quy trình: Kiểm tra ngày hợp lệ -> Check xe có bị trùng lịch không -> Tính giá -> Lưu đơn -> Tạo hóa đơn (Invoice).
     */
    @Override
    @Transactional
    public BookingResponse createBooking(BookingCreateRequest request, String currentUserPhone) {
        if(request.startDate().isAfter(request.endDate())){
            throw new AppException(ErrorCode.BOOKING_INVALID_DATE_RANGE);
        }
        User user = userRepository.findByPhone(currentUserPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Car car = carRepository.findById(request.carId())
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, request.carId()));

        List<Booking> overlapping = bookingRepository.findOverlappingBookings(
                car.getCarId(),
                request.startDate(),
                request.endDate()
        );

        if (!overlapping.isEmpty()) {
            Booking conflict = overlapping.get(0);
            throw new AppException(ErrorCode.BOOKING_DATE_CONFLICT, conflict.getStartDate(), conflict.getEndDate());
        }

        long days = request.startDate().until(request.endDate()).getDays() + 1;
        BigDecimal totalPrice = car.getPricePerDay().multiply(BigDecimal.valueOf(days));

        Booking booking = new Booking();
        booking.setUser(user);
        booking.setCar(car);
        booking.setStartDate(request.startDate());
        booking.setEndDate(request.endDate());
        booking.setTotalPrice(totalPrice);
        booking.setPickupAddress(request.pickupAddress());
        booking.setPickupLatitude(request.pickupLatitude());
        booking.setPickupLongitude(request.pickupLongitude());
        booking.setDropoffAddress(request.dropoffAddress());
        booking.setDropoffLatitude(request.dropoffLatitude());
        booking.setDropoffLongitude(request.dropoffLongitude());
        booking.setStatus(BookingStatus.PENDING);

        booking = bookingRepository.save(booking);

        car.setStatus(CarStatus.PENDING);
        carRepository.save(car);

        invoiceService.createInvoiceForBooking(booking);
        notificationService.send(user,
                "Đặt xe thành công",
                "Bạn đã đặt xe " + car.getBrand() + " " + car.getName() + " từ " + booking.getStartDate() + " đến " + booking.getEndDate(),
                NotificationType.BOOKING_CREATED, booking.getBookingId());
        return mapToResponse(booking);
    }

    @Override
    public Page<BookingSummaryResponse> getAllBookings(Pageable pageable) {
        return bookingRepository.findAll(pageable).map(this::mapToSummary);
    }

    @Override
    public Page<BookingSummaryResponse> getMyBookings(String currentUserPhone, Pageable pageable) {
        User user = userRepository.findByPhone(currentUserPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        return bookingRepository.findByUserUserId(user.getUserId(), pageable).map(this::mapToSummary);
    }

    @Override
    public BookingResponse getBookingById(Long bookingId, String currentUserPhone, boolean isAdmin) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (!isAdmin) {
            User currentUser = userRepository.findByPhone(currentUserPhone)
                    .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

            if (!booking.getUser().getUserId().equals(currentUser.getUserId())) {
                throw new AppException(ErrorCode.BOOKING_ACCESS_DENIED);
            }
        }

        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse cancelBooking(Long bookingId, String currentUserPhone, boolean isAdmin) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if(!isAdmin) {
            User currentUser = userRepository.findByPhone(currentUserPhone)
                    .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND, bookingId));

            if(!booking.getUser().getUserId().equals(currentUser.getUserId())) {
                throw new AppException(ErrorCode.BOOKING_ACCESS_DENIED);
            }

            if(booking.getStatus() != BookingStatus.PENDING) {
                throw new AppException(ErrorCode.BOOKING_CANCEL_NOT_ALLOWED, booking.getStatus());
            }
        }

        if(booking.getStatus() == BookingStatus.CANCELLED) {
            throw new AppException(ErrorCode.BOOKING_INVALID_STATUS_TRANSITION, BookingStatus.CANCELLED, BookingStatus.COMPLETED);
        }

        booking.setStatus(BookingStatus.CANCELLED);
        booking = bookingRepository.save(booking);

        // Release the car back to AVAILABLE when cancelled
        Car car = booking.getCar();
        if (car != null && (car.getStatus() == CarStatus.PENDING || car.getStatus() == CarStatus.BOOKED)) {
            car.setStatus(CarStatus.AVAILABLE);
            carRepository.save(car);
        }

        notificationService.send(booking.getUser(),
                "Booking đã bị hủy",
                "Đơn đặt xe #" + booking.getBookingId() + " đã được hủy thành công.",
                NotificationType.BOOKING_CANCELLED, booking.getBookingId());

        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse confirmBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.PENDING) {
            throw new AppException(ErrorCode.BOOKING_INVALID_STATUS_TRANSITION,
                    booking.getStatus(), BookingStatus.CONFIRMED);
        }

        booking.setStatus(BookingStatus.CONFIRMED);
        booking = bookingRepository.save(booking);

        // Mark car as booked
        Car car = booking.getCar();
        if (car != null) {
            car.setStatus(CarStatus.BOOKED);
            carRepository.save(car);
        }

        notificationService.send(booking.getUser(),
                "Booking đã được xác nhận",
                "Đơn đặt xe #" + booking.getBookingId() + " đã được xác nhận. Hãy chuẩn bị cho chuyến đi của bạn!",
                NotificationType.BOOKING_CONFIRMED, booking.getBookingId());

        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse handoverBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new AppException(ErrorCode.BOOKING_INVALID_STATUS_TRANSITION,
                    booking.getStatus(), BookingStatus.IN_PROGRESS);
        }

        booking.setStatus(BookingStatus.IN_PROGRESS);
        booking = bookingRepository.save(booking);

        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse completeBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.IN_PROGRESS) {
            throw new AppException(ErrorCode.BOOKING_INVALID_STATUS_TRANSITION,
                    booking.getStatus(), BookingStatus.COMPLETED);
        }

        booking.setStatus(BookingStatus.COMPLETED);
        booking = bookingRepository.save(booking);

        // Release the car back to AVAILABLE
        Car car = booking.getCar();
        if (car != null) {
            car.setStatus(CarStatus.AVAILABLE);
            carRepository.save(car);
        }

        notificationService.send(booking.getUser(),
                "Chuyến đi hoàn tất",
                "Cảm ơn bạn đã sử dụng GoRento! Đơn #" + booking.getBookingId() + " đã hoàn thành. Hãy để lại đánh giá nhé.",
                NotificationType.BOOKING_COMPLETED, booking.getBookingId());

        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public List<Long> expirePendingUnpaidBookings(LocalDateTime cutoff) {
        List<Booking> candidates = bookingRepository.findExpiredPendingUnpaidBookings(cutoff);
        if (candidates.isEmpty()) {
            return List.of();
        }

        List<Long> expiredBookingIds = new ArrayList<>();

        for (Booking booking : candidates) {
            Invoice invoice = booking.getInvoice();
            Car car = booking.getCar();

            boolean isEligible = booking.getStatus() == BookingStatus.PENDING
                    && invoice != null
                    && invoice.getStatus() == InvoiceStatus.UNPAID
                    && car != null
                    && car.getStatus() == CarStatus.PENDING;

            if (!isEligible) {
                continue;
            }

            booking.setStatus(BookingStatus.CANCELLED);
            invoice.setStatus(InvoiceStatus.FAILED);
            car.setStatus(CarStatus.AVAILABLE);

            expiredBookingIds.add(booking.getBookingId());

        }

        return expiredBookingIds;
    }

    @Override
    @Transactional
    public BookingResponse updatePickupLocation(Long bookingId, String currentUserPhone, BookingLocationRequest request) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));
        verifyOwner(booking, currentUserPhone);
        booking.setPickupAddress(request.address());
        booking.setPickupLatitude(request.latitude());
        booking.setPickupLongitude(request.longitude());
        booking = bookingRepository.save(booking);
        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse updateDropoffLocation(Long bookingId, String currentUserPhone, BookingLocationRequest request) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));
        verifyOwner(booking, currentUserPhone);
        booking.setDropoffAddress(request.address());
        booking.setDropoffLatitude(request.latitude());
        booking.setDropoffLongitude(request.longitude());
        booking = bookingRepository.save(booking);
        return mapToResponse(booking);
    }

    private void verifyOwner(Booking booking, String currentUserPhone) {
        User currentUser = userRepository.findByPhone(currentUserPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        if (!booking.getUser().getUserId().equals(currentUser.getUserId())) {
            throw new AppException(ErrorCode.BOOKING_ACCESS_DENIED);
        }
    }

    private BookingResponse mapToResponse(Booking booking) {
        return new BookingResponse(
                booking.getBookingId(),
                booking.getUser().getUserId(),
                booking.getInvoice() != null ? booking.getInvoice().getInvoiceId() : null,
                booking.getUser().getName(),
                booking.getUser().getPhone(),
                booking.getCar().getCarId(),
                booking.getCar().getName(),
                booking.getCar().getBrand(),
                booking.getCar().getLicensePlate(),
                booking.getStartDate(),
                booking.getEndDate(),
                booking.getTotalPrice(),
                booking.getStatus(),
                booking.getCreatedAt(),
                booking.getUpdatedAt(),
                booking.getPickupAddress(),
                booking.getPickupLatitude(),
                booking.getPickupLongitude(),
                booking.getDropoffAddress(),
                booking.getDropoffLatitude(),
                booking.getDropoffLongitude()
        );
    }

    private BookingSummaryResponse mapToSummary(Booking booking) {
        return new BookingSummaryResponse(
                booking.getBookingId(),
                booking.getCar().getName(),
                booking.getCar().getBrand(),
                booking.getCar().getLicensePlate(),
                booking.getStartDate(),
                booking.getEndDate(),
                booking.getTotalPrice(),
                booking.getStatus()
        );
    }
}
