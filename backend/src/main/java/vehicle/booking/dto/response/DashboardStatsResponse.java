package vehicle.booking.dto.response;

import java.math.BigDecimal;

public record DashboardStatsResponse(
        long totalUsers,
        long totalCars,
        long totalBookings,
        long pendingBookings,
        long confirmedBookings,
        long inProgressBookings,
        long completedBookings,
        long cancelledBookings,
        BigDecimal totalRevenue,
        long availableCars,
        long bookedCars
) {}
