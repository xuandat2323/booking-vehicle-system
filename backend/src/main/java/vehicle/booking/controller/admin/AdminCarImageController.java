package vehicle.booking.controller.admin;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.CarImageResponse;
import vehicle.booking.service.CarImageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/admin/cars/{carId}/images")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminCarImageController {

    private final CarImageService carImageService;

    @PostMapping
    public ResponseEntity<ApiResponse<CarImageResponse>> uploadCarImage(
            @PathVariable Long carId,
            @RequestPart("file") MultipartFile file
    ) {
        CarImageResponse response = carImageService.uploadCarImage(carId, file);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(true, "Tải hình ảnh xe thành công", response));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<CarImageResponse>>> getCarImages(@PathVariable Long carId) {
        List<CarImageResponse> responses = carImageService.getCarImagesByCarId(carId);
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách hình ảnh xe thành công", responses));
    }

    @GetMapping("/primary")
    public ResponseEntity<ApiResponse<CarImageResponse>> getPrimaryCarImage(@PathVariable Long carId) {
        CarImageResponse primaryImage = carImageService.getPrimaryImageByCarId(carId);
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy ảnh đại diện thành công", primaryImage));
    }

    @PatchMapping("/{carImageId}/primary")
    public ResponseEntity<ApiResponse<CarImageResponse>> setPrimaryImage(
            @PathVariable Long carId,
            @PathVariable Long carImageId
    ) {
        CarImageResponse response = carImageService.setPrimaryImage(carId, carImageId);
        return ResponseEntity.ok(new ApiResponse<>(true, "Đặt ảnh đại diện thành công", response));
    }
}
