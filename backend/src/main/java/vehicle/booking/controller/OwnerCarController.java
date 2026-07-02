package vehicle.booking.controller;

import vehicle.booking.dto.request.CarCreateRequest;
import vehicle.booking.dto.request.CarUpdateRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.CarResponse;
import vehicle.booking.dto.response.CarSummaryResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.service.CarService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/owner/cars")
@RequiredArgsConstructor
public class OwnerCarController {

    private final CarService carService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<CarSummaryResponse>>> getMyCars(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Page<CarSummaryResponse> result = carService.getMyOwnerCars(
                userDetails.getUsername(), PageRequest.of(page, Math.min(size, 50)));
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách xe thành công", PageResponse.of(result)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CarResponse>> createCar(
            @RequestBody CarCreateRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        CarResponse car = carService.createCarByOwner(request, userDetails.getUsername());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(true, "Đăng xe thành công", car));
    }

    @PutMapping("/{carId}")
    public ResponseEntity<ApiResponse<CarResponse>> updateCar(
            @PathVariable Long carId,
            @RequestBody CarUpdateRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        CarResponse car = carService.updateCarByOwner(carId, request, userDetails.getUsername());
        return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật xe thành công", car));
    }

    @DeleteMapping("/{carId}")
    public ResponseEntity<ApiResponse<Void>> deleteCar(
            @PathVariable Long carId,
            @AuthenticationPrincipal UserDetails userDetails) {
        carService.deleteCarByOwner(carId, userDetails.getUsername());
        return ResponseEntity.ok(new ApiResponse<>(true, "Ẩn xe thành công", null));
    }
}
