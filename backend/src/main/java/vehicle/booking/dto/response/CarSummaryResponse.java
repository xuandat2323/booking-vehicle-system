package vehicle.booking.dto.response;

import java.math.BigDecimal;

import vehicle.booking.entity.enums.CarStatus;

public record CarSummaryResponse(
        Long id,
        String name,
        String brand,
        String licensePlate,
        BigDecimal pricePerDay,
        CarStatus status,
        String imageUrl,
        Integer seats,
        String location,
        Long branchId,
        String branchName,
        java.math.BigDecimal latitude,
        java.math.BigDecimal longitude,
        Double averageRating,
        Long reviewCount,
        /** Chỉ có giá trị khi tìm xe quanh một toạ độ (API /api/cars/nearby). */
        Double distanceKm
) {
}
