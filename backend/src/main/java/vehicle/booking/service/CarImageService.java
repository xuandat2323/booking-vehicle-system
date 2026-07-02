package vehicle.booking.service;

import vehicle.booking.dto.response.CarImageResponse;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

public interface CarImageService {

    CarImageResponse uploadCarImage(Long carId, MultipartFile file);

    List<CarImageResponse> getCarImagesByCarId(Long carId);

    CarImageResponse getPrimaryImageByCarId(Long carId);

    CarImageResponse setPrimaryImage(Long carId, Long carImageId);

    void deleteCarImage(Long carId, Long carImageId);
}
