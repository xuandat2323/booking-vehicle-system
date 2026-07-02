package vehicle.booking.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

public record CarResponse(
        Long id,
        String name,
        String brand,
        String model,
        String licensePlate,
        BigDecimal pricePerDay,
        CarStatus status,
        String imageUrl,
        Integer seats,
        Transmission transmission,
        FuelType fuelType,
        String location,
        java.math.BigDecimal latitude,
        java.math.BigDecimal longitude,
        String locationSource,
        LocalDateTime locationUpdatedAt,
        LocalDateTime createdAt,
        LocalDateTime updatedAt,
        Double averageRating,
        Long reviewCount
) {
}
