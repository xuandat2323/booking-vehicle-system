package vehicle.booking.controller.admin;

import vehicle.booking.dto.request.CarCreateRequest;
import vehicle.booking.dto.request.CarLocationUpdateRequest;
import vehicle.booking.dto.request.CarUpdateRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.CarResponse;
import vehicle.booking.service.CarService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/cars")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminCarController {

    private final CarService carService;

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