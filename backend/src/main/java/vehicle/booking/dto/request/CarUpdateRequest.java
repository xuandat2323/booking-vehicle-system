package vehicle.booking.dto.request;

import java.math.BigDecimal;

import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

public record CarUpdateRequest(
        String name,
        String brand,
        String model,
        String licensePlate,
        BigDecimal pricePerDay,
        CarStatus status,
        Integer seats,
        Transmission transmission,
        FuelType fuelType,
        String location
) {
}

