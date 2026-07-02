package vehicle.booking.controller;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.CarImageResponse;
import vehicle.booking.entity.Car;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.CarRepository;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.service.CarImageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/owner/cars/{carId}/images")
@RequiredArgsConstructor
public class OwnerCarImageController {

    private final CarImageService carImageService;
    private final CarRepository carRepository;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<ApiResponse<List<CarImageResponse>>> getImages(
            @PathVariable Long carId,
            @AuthenticationPrincipal UserDetails userDetails) {
        verifyOwnership(carId, userDetails.getUsername());
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách ảnh thành công",
                carImageService.getCarImagesByCarId(carId)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CarImageResponse>> uploadImage(
            @PathVariable Long carId,
            @RequestPart("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) {
        verifyOwnership(carId, userDetails.getUsername());
        CarImageResponse response = carImageService.uploadCarImage(carId, file);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(true, "Tải ảnh lên thành công", response));
    }

    @DeleteMapping("/{imageId}")
    public ResponseEntity<ApiResponse<Void>> deleteImage(
            @PathVariable Long carId,
            @PathVariable Long imageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        verifyOwnership(carId, userDetails.getUsername());
        carImageService.deleteCarImage(carId, imageId);
        return ResponseEntity.ok(new ApiResponse<>(true, "Xóa ảnh thành công", null));
    }

    @PatchMapping("/{imageId}/primary")
    public ResponseEntity<ApiResponse<CarImageResponse>> setPrimary(
            @PathVariable Long carId,
            @PathVariable Long imageId,
            @AuthenticationPrincipal UserDetails userDetails) {
        verifyOwnership(carId, userDetails.getUsername());
        CarImageResponse response = carImageService.setPrimaryImage(carId, imageId);
        return ResponseEntity.ok(new ApiResponse<>(true, "Đặt ảnh đại diện thành công", response));
    }

    private void verifyOwnership(Long carId, String ownerPhone) {
        Car car = carRepository.findById(carId)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, carId));
        var owner = userRepository.findByPhone(ownerPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        if (car.getOwner() == null || !car.getOwner().getUserId().equals(owner.getUserId())) {
            throw new AppException(ErrorCode.CAR_NOT_OWNER);
        }
    }
}
