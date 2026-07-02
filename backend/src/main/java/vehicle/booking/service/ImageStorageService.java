package vehicle.booking.service;

import org.springframework.web.multipart.MultipartFile;

public interface ImageStorageService {

    StoredImage uploadCarImage(MultipartFile file, Long carId);
    void deleteByPublicId(String publicId);

    record StoredImage(
            String url,
            String publicId,
            String format,
            Long bytes
    ) {
    }
}
