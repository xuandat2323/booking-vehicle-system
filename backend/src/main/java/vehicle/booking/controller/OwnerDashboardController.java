package vehicle.booking.controller;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.entity.User;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.repository.CarRepository;
import vehicle.booking.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/owner/dashboard")
@RequiredArgsConstructor
public class OwnerDashboardController {

    private final UserRepository userRepository;
    private final CarRepository carRepository;
    private final BookingRepository bookingRepository;

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> getDashboard(
            @AuthenticationPrincipal UserDetails userDetails) {
        User owner = userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        Long ownerId = owner.getUserId();

        long totalCars = carRepository.findByOwnerUserId(ownerId, org.springframework.data.domain.Pageable.unpaged()).getTotalElements();
        long totalBookings = bookingRepository.findByCarOwnerUserId(ownerId, org.springframework.data.domain.Pageable.unpaged()).getTotalElements();
        BigDecimal totalEarnings = bookingRepository.sumCompletedEarningsByOwnerId(ownerId);

        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy thống kê thành công", Map.of(
                "totalCars", totalCars,
                "totalBookings", totalBookings,
                "totalEarnings", totalEarnings != null ? totalEarnings : BigDecimal.ZERO,
                "ownerName", owner.getName()
        )));
    }
}
