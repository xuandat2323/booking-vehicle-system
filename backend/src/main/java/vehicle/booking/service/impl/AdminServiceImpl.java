package vehicle.booking.service.impl;

import vehicle.booking.dto.response.DashboardStatsResponse;
import vehicle.booking.dto.response.UserSummaryResponse;
import vehicle.booking.entity.User;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.repository.CarRepository;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.service.AdminService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminServiceImpl implements AdminService {

    private final UserRepository userRepository;
    private final BookingRepository bookingRepository;
    private final CarRepository carRepository;

    @Override
    public Page<UserSummaryResponse> getAllUsers(String search, Pageable pageable) {
        return userRepository.searchUsers(search, pageable).map(this::mapToUserSummary);
    }

    @Override
    public UserSummaryResponse getUserById(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        return mapToUserSummary(user);
    }

    @Override
    @Transactional
    public void toggleUserStatus(Long userId, boolean enabled) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        // Prevent disabling admin accounts
        if ("ADMIN".equals(user.getRole())) {
            throw new AppException(ErrorCode.AUTH_FORBIDDEN);
        }

        user.setRole(enabled ? "USER" : "DISABLED");
        userRepository.save(user);
        log.info("User {} status changed to {}", userId, enabled ? "USER" : "DISABLED");
    }

    @Override
    public DashboardStatsResponse getDashboardStats() {
        long totalUsers = userRepository.countByRole("USER");
        long totalCars = carRepository.count();

        long totalBookings = bookingRepository.count();
        long pendingBookings = bookingRepository.findByStatus(BookingStatus.PENDING).size()
                + bookingRepository.findByStatus(BookingStatus.DEPOSIT_PAID).size();
        long confirmedBookings = bookingRepository.findByStatus(BookingStatus.CONFIRMED).size();
        long inProgressBookings = bookingRepository.findByStatus(BookingStatus.RENTING).size()
                + bookingRepository.findByStatus(BookingStatus.RETURNED).size();
        long completedBookings = bookingRepository.findByStatus(BookingStatus.COMPLETED).size();
        long cancelledBookings = bookingRepository.findByStatus(BookingStatus.CANCELLED).size();

        // Calculate total revenue from completed bookings
        BigDecimal totalRevenue = bookingRepository.findByStatus(BookingStatus.COMPLETED).stream()
                .map(b -> b.getTotalPrice())
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        long availableCars = carRepository.findByStatus(CarStatus.AVAILABLE).size();
        long bookedCars = carRepository.findByStatus(CarStatus.BOOKED).size()
                + carRepository.findByStatus(CarStatus.PENDING).size();

        return new DashboardStatsResponse(
                totalUsers, totalCars, totalBookings,
                pendingBookings, confirmedBookings, inProgressBookings,
                completedBookings, cancelledBookings,
                totalRevenue, availableCars, bookedCars
        );
    }

    private UserSummaryResponse mapToUserSummary(User user) {
        long totalBookings = bookingRepository.findByUserUserIdAndStatus(user.getUserId(), BookingStatus.COMPLETED).size()
                + bookingRepository.findByUserUserIdAndStatus(user.getUserId(), BookingStatus.PENDING).size()
                + bookingRepository.findByUserUserIdAndStatus(user.getUserId(), BookingStatus.DEPOSIT_PAID).size()
                + bookingRepository.findByUserUserIdAndStatus(user.getUserId(), BookingStatus.CONFIRMED).size()
                + bookingRepository.findByUserUserIdAndStatus(user.getUserId(), BookingStatus.RENTING).size()
                + bookingRepository.findByUserUserIdAndStatus(user.getUserId(), BookingStatus.RETURNED).size();

        return new UserSummaryResponse(
                user.getUserId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                user.getDriveLicense(),
                user.getRole(),
                totalBookings
        );
    }
}
