package vehicle.booking.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vehicle.booking.dto.request.VehicleTrackingUpdateRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.VehicleTrackingHistoryResponse;
import vehicle.booking.dto.response.VehicleTrackingResponse;
import vehicle.booking.service.VehicleTrackingService;

import java.util.List;

@RestController
@RequestMapping("/api/cars")
@RequiredArgsConstructor
public class VehicleTrackingController {

    private final VehicleTrackingService vehicleTrackingService;

    @PutMapping("/{carId}/tracking")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<VehicleTrackingResponse>> updateCurrentLocation(
            @PathVariable Long carId,
            @RequestBody VehicleTrackingUpdateRequest request) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật vị trí hiện tại của xe thành công", vehicleTrackingService.updateCurrentLocation(carId, request)));
    }

    @GetMapping("/{carId}/tracking")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<VehicleTrackingResponse>> getCurrentLocation(@PathVariable Long carId) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy vị trí hiện tại của xe thành công", vehicleTrackingService.getCurrentLocation(carId)));
    }

    @GetMapping("/{carId}/tracking/history")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<List<VehicleTrackingHistoryResponse>>> getTrackingHistory(@PathVariable Long carId) {
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy lịch sử vị trí xe thành công", vehicleTrackingService.getTrackingHistory(carId)));
    }
}
