package vehicle.booking.dto.request;

import jakarta.validation.constraints.DecimalMin;

import java.math.BigDecimal;

import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

/**
 * Update là partial update: field null nghĩa là "giữ nguyên giá trị cũ",
 * nên không dùng @NotBlank/@NotNull ở đây — chỉ validate định dạng khi field có giá trị.
 */
public record CarUpdateRequest(
        String name,
        String brand,
        String model,
        String licensePlate,

        @DecimalMin(value = "0.0", inclusive = false, message = "Giá thuê theo ngày phải lớn hơn 0")
        BigDecimal pricePerDay,

        CarStatus status,
        Integer seats,
        Transmission transmission,
        FuelType fuelType,
        String location,
        Long branchId
) {
}

