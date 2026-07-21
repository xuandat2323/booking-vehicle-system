package vehicle.booking.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

public record CarCreateRequest(
        @NotBlank(message = "Tên xe không được để trống")
        String name,

        @NotBlank(message = "Hãng xe không được để trống")
        String brand,

        String model,

        @NotBlank(message = "Biển số xe không được để trống")
        String licensePlate,

        @NotNull(message = "Giá thuê theo ngày không được để trống")
        @DecimalMin(value = "0.0", inclusive = false, message = "Giá thuê theo ngày phải lớn hơn 0")
        BigDecimal pricePerDay,

        CarStatus carStatus,
        Integer seats,
        Transmission transmission,
        FuelType fuelType,
        String location,
        Long branchId
) {
}

