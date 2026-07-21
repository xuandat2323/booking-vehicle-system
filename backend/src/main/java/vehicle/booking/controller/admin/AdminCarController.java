package vehicle.booking.controller.admin;

import vehicle.booking.dto.request.CarCreateRequest;
import vehicle.booking.dto.request.CarLocationUpdateRequest;
import vehicle.booking.dto.request.CarUpdateRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.CarResponse;
import vehicle.booking.dto.response.CarSummaryResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;
import vehicle.booking.service.CarService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/admin/cars")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminCarController {

    private final CarService carService;

    @GetMapping()
    public ResponseEntity<ApiResponse<PageResponse<CarSummaryResponse>>> getAllCars(
            @RequestParam(required = false, defaultValue = "false") boolean onlyAvailable,
            @RequestParam(required = false) String brand,
            @RequestParam(required = false) String name,
            @RequestParam(required = false) String location,
            @RequestParam(required = false) Transmission transmission,
            @RequestParam(required = false) FuelType fuelType,
            @RequestParam(required = false) BigDecimal minPrice,
            @RequestParam(required = false) BigDecimal maxPrice,
            @RequestParam(required = false) List<Integer> seats,
            @RequestParam(required = false) Long branchId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 100));

        boolean hasAdvancedFilters = brand != null
                || minPrice != null
                || maxPrice != null
                || name != null
                || location != null
                || transmission != null
                || fuelType != null
                || (seats != null && !seats.isEmpty())
                || branchId != null;

        Page<CarSummaryResponse> result = hasAdvancedFilters
                ? carService.searchCars(onlyAvailable, brand, name, location, transmission, fuelType,
                        minPrice, maxPrice, seats, branchId, pageable)
                : carService.getAllCars(onlyAvailable, pageable);

        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy danh sách xe thành công", PageResponse.of(result)));
    }

    @PostMapping()
    public ResponseEntity<ApiResponse<CarResponse>> createCar(
            @RequestBody @Valid CarCreateRequest request) {
        CarResponse created = carService.createCar(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(true, "Tạo xe thành công", created));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<CarResponse>> updateCar(
            @PathVariable Long id,
            @RequestBody @Valid CarUpdateRequest request) {
        CarResponse updated = carService.updateCar(id, request);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Cập nhật xe thành công", updated));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<String>> deleteCar(@PathVariable Long id) {
        carService.deleteCar(id);
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Xóa xe thành công (soft delete)", null));
    }

    @PutMapping("/{id}/location")
    public ResponseEntity<ApiResponse<CarResponse>> updateLocation(
            @PathVariable Long id,
            @RequestBody CarLocationUpdateRequest request) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật vị trí xe thành công", carService.updateCarLocation(id, request)));
    }
}