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
import vehicle.booking.repository.BranchRepository;
import vehicle.booking.repository.CarRepository;
import vehicle.booking.repository.InvoiceRepository;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.realtime.RealtimeEventHub;
import vehicle.booking.entity.enums.NotificationType;
import vehicle.booking.service.BookingService;
import vehicle.booking.service.InvoiceService;
import vehicle.booking.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
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
    private final BranchRepository branchRepository;
    private final InvoiceRepository invoiceRepository;
    private final UserRepository userRepository;
    private final InvoiceService invoiceService;
    private final NotificationService notificationService;
    private final RealtimeEventHub realtimeEventHub;

    @Value("${booking.expiration.pending-payment-timeout:15m}")
    private Duration pendingPaymentTimeout;

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

        // Hủy đơn PENDING quá hạn cọc trước khi kiểm tra trùng lịch (không chờ scheduler)
        expirePendingUnpaidBookings(LocalDateTime.now().minus(pendingPaymentTimeout));

        List<Booking> overlapping = bookingRepository.findOverlappingBookings(
                car.getCarId(),
                request.startDate(),
                request.endDate()
        );

        if (!overlapping.isEmpty()) {
            Booking conflict = overlapping.get(0);
            boolean ownPending = conflict.getStatus() == BookingStatus.PENDING
                    && conflict.getUser().getUserId().equals(user.getUserId());
            if (ownPending) {
                throw new AppException(
                        ErrorCode.BOOKING_OWN_PENDING_EXISTS,
                        conflict.getStartDate(),
                        conflict.getEndDate()
                );
            }
            throw new AppException(ErrorCode.BOOKING_DATE_CONFLICT, conflict.getStartDate(), conflict.getEndDate());
        }

        long days = request.startDate().until(request.endDate()).getDays() + 1;
        BigDecimal totalPrice = car.getPricePerDay().multiply(BigDecimal.valueOf(days));
        BigDecimal depositAmount = totalPrice.multiply(new BigDecimal("0.30")).setScale(0, java.math.RoundingMode.HALF_UP);

        Booking booking = new Booking();
        booking.setUser(user);
        booking.setCar(car);
        booking.setStartDate(request.startDate());
        booking.setEndDate(request.endDate());
        booking.setTotalPrice(totalPrice);
        booking.setDepositAmount(depositAmount);
        booking.setPickupAddress(request.pickupAddress());
        booking.setPickupLatitude(request.pickupLatitude());
        booking.setPickupLongitude(request.pickupLongitude());
        booking.setDropoffAddress(request.dropoffAddress());
        booking.setDropoffLatitude(request.dropoffLatitude());
        booking.setDropoffLongitude(request.dropoffLongitude());
        if (request.dropoffBranchId() != null) {
            booking.setDropoffBranch(resolveBranch(request.dropoffBranchId()));
        }
        booking.setStatus(BookingStatus.PENDING);

        booking = bookingRepository.save(booking);

        car.setStatus(CarStatus.PENDING);
        carRepository.save(car);

        invoiceService.createInvoiceForBooking(booking);
        String carLabel = car.getBrand() + " " + car.getName();
        notificationService.send(user,
                "Đặt xe thành công",
                "Bạn đã đặt xe " + carLabel + " từ " + booking.getStartDate()
                        + " đến " + booking.getEndDate() + ". Vui lòng đặt cọc 30% để giữ xe.",
                NotificationType.BOOKING_CREATED, booking.getBookingId());
        notificationService.sendToAdmins(
                "Đơn thuê mới",
                "Khách " + user.getName() + " vừa tạo đơn #" + booking.getBookingId()
                        + " thuê " + carLabel + ".",
                NotificationType.BOOKING_CREATED, booking.getBookingId());
        publishBooking(booking);
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
                "Đơn đã bị hủy",
                "Đơn đặt xe #" + booking.getBookingId() + " đã được hủy.",
                NotificationType.BOOKING_CANCELLED, booking.getBookingId());
        notificationService.sendToAdmins(
                "Đơn bị hủy",
                "Đơn #" + booking.getBookingId() + " của khách "
                        + booking.getUser().getName() + " đã bị hủy.",
                NotificationType.BOOKING_CANCELLED, booking.getBookingId());

        publishBooking(booking);
        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse confirmBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.DEPOSIT_PAID) {
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
                "Đơn đã được xác nhận",
                "Đơn #" + booking.getBookingId()
                        + " đã được xác nhận. Hãy đến điểm nhận xe đúng lịch đã đặt.",
                NotificationType.BOOKING_CONFIRMED, booking.getBookingId());

        publishBooking(booking);
        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse handoverBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new AppException(ErrorCode.BOOKING_INVALID_STATUS_TRANSITION,
                    booking.getStatus(), BookingStatus.RENTING);
        }

        booking.setStatus(BookingStatus.RENTING);
        booking = bookingRepository.save(booking);

        // Khi admin bàn giao xe: coi như đã chốt thanh toán → hóa đơn PAID.
        Invoice invoice = booking.getInvoice();
        if (invoice != null && invoice.getStatus() != InvoiceStatus.PAID) {
            invoice.setStatus(InvoiceStatus.PAID);
            invoiceRepository.save(invoice);
            log.info("Invoice {} marked PAID after handover of booking {}",
                    invoice.getInvoiceId(), booking.getBookingId());
        }

        notificationService.send(booking.getUser(),
                "Bắt đầu chuyến đi",
                "Bạn đã nhận xe. Chuyến đi #" + booking.getBookingId() + " đang diễn ra.",
                NotificationType.BOOKING_RENTING, booking.getBookingId());

        publishBooking(booking);
        return mapToResponse(booking);
    }

    @Override
    @Transactional
    public BookingResponse returnBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.RENTING) {
            throw new AppException(ErrorCode.BOOKING_INVALID_STATUS_TRANSITION,
                    booking.getStatus(), BookingStatus.RETURNED);
        }

        booking.setStatus(BookingStatus.RETURNED);
        booking = bookingRepository.save(booking);

        // Khi khách trả xe: chuyển vị trí xe về chi nhánh khách đã chọn làm điểm trả.
        moveCarToDropoffBranch(booking);

        notificationService.send(booking.getUser(),
                "Đã ghi nhận trả xe",
                "Đơn #" + booking.getBookingId()
                        + " đã trả xe. Vui lòng chờ admin kiểm tra và hoàn tất đơn.",
                NotificationType.BOOKING_RETURNED, booking.getBookingId());
        notificationService.sendToAdmins(
                "Khách đã trả xe",
                "Đơn #" + booking.getBookingId() + " của khách "
                        + booking.getUser().getName() + " đã trả xe, cần hoàn tất đơn.",
                NotificationType.BOOKING_RETURNED, booking.getBookingId());

        publishBooking(booking);
        return mapToResponse(booking);
    }

    /**
     * Sau khi khách trả xe, cập nhật cơ sở & toạ độ của xe theo chi nhánh trả xe.
     * Lần thuê tiếp theo, điểm đón mặc định sẽ là chi nhánh này.
     */
    private void moveCarToDropoffBranch(Booking booking) {
        Branch dropoffBranch = booking.getDropoffBranch();
        Car car = booking.getCar();
        if (dropoffBranch == null || car == null) {
            return;
        }

        car.setBranch(dropoffBranch);
        if (dropoffBranch.getLatitude() != null && dropoffBranch.getLongitude() != null) {
            car.setLatitude(dropoffBranch.getLatitude());
            car.setLongitude(dropoffBranch.getLongitude());
            car.setLocationSource("BRANCH");
            car.setLocationUpdatedAt(LocalDateTime.now());
        }
        String branchAddress = dropoffBranch.getAddress();
        if (branchAddress != null && !branchAddress.isBlank()) {
            car.setLocation(branchAddress);
        }
        carRepository.save(car);
        log.info("Car {} moved to dropoff branch {} after return of booking {}",
                car.getCarId(), dropoffBranch.getBranchId(), booking.getBookingId());
    }

    private Branch resolveBranch(Long branchId) {
        return branchRepository.findById(branchId)
                .orElseThrow(() -> new AppException(ErrorCode.BRANCH_NOT_FOUND, branchId));
    }

    @Override
    @Transactional
    public BookingResponse returnBooking(Long bookingId, String currentUserPhone) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        User currentUser = userRepository.findByPhone(currentUserPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        if (!booking.getUser().getUserId().equals(currentUser.getUserId())) {
            throw new AppException(ErrorCode.BOOKING_ACCESS_DENIED);
        }

        return returnBooking(bookingId);
    }

    @Override
    @Transactional
    public BookingResponse completeBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.RETURNED) {
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
                "Cảm ơn bạn đã dùng GoRento! Đơn #" + booking.getBookingId()
                        + " đã hoàn thành. Hãy để lại đánh giá nhé.",
                NotificationType.BOOKING_COMPLETED, booking.getBookingId());

        publishBooking(booking);
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
                    && invoice.getStatus() == InvoiceStatus.UNPAID;

            if (!isEligible) {
                continue;
            }

            booking.setStatus(BookingStatus.CANCELLED);
            invoice.setStatus(InvoiceStatus.FAILED);
            if (car != null) {
                car.setStatus(CarStatus.AVAILABLE);
            }

            notificationService.send(booking.getUser(),
                    "Đơn đã bị hủy",
                    "Đơn #" + booking.getBookingId()
                            + " đã hủy vì quá hạn đặt cọc.",
                    NotificationType.BOOKING_CANCELLED, booking.getBookingId());
            notificationService.sendToAdmins(
                    "Đơn hết hạn cọc",
                    "Đơn #" + booking.getBookingId() + " của khách "
                            + booking.getUser().getName() + " đã hủy vì quá hạn đặt cọc.",
                    NotificationType.BOOKING_CANCELLED, booking.getBookingId());

            expiredBookingIds.add(booking.getBookingId());
            publishBooking(booking);
        }

        return expiredBookingIds;
    }

    @Override
    @Transactional
    public BookingResponse updatePickupLocation(Long bookingId, String currentUserPhone, BookingLocationRequest request) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));
        verifyOwner(booking, currentUserPhone);
        // Điểm nhận cố định theo chi nhánh của xe — không cho khách đổi sau khi tạo đơn.
        throw new AppException(
                ErrorCode.BOOKING_LOCATION_UPDATE_NOT_ALLOWED,
                "điểm nhận xe",
                booking.getStatus());
    }

    @Override
    @Transactional
    public BookingResponse updateDropoffLocation(Long bookingId, String currentUserPhone, BookingLocationRequest request) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));
        verifyOwner(booking, currentUserPhone);
        if (!canUpdateDropoff(booking.getStatus())) {
            throw new AppException(
                    ErrorCode.BOOKING_LOCATION_UPDATE_NOT_ALLOWED,
                    "điểm trả xe",
                    booking.getStatus());
        }
        booking.setDropoffAddress(request.address());
        booking.setDropoffLatitude(request.latitude());
        booking.setDropoffLongitude(request.longitude());
        if (request.branchId() != null) {
            booking.setDropoffBranch(resolveBranch(request.branchId()));
        }
        booking = bookingRepository.save(booking);
        publishBooking(booking);
        return mapToResponse(booking);
    }

    /** Cho đổi điểm trả đến trước khi đơn đã RETURNED/COMPLETED/CANCELLED. */
    private boolean canUpdateDropoff(BookingStatus status) {
        return status == BookingStatus.PENDING
                || status == BookingStatus.DEPOSIT_PAID
                || status == BookingStatus.CONFIRMED
                || status == BookingStatus.RENTING;
    }

    private void publishBooking(Booking booking) {
        if (booking == null || booking.getUser() == null) {
            return;
        }
        realtimeEventHub.publishBookingUpdated(
                booking.getUser().getUserId(),
                booking.getBookingId(),
                booking.getStatus() != null ? booking.getStatus().name() : null
        );
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
                booking.getDepositAmount(),
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
                booking.getDepositAmount(),
                booking.getStatus()
        );
    }
}
