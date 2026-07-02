package vehicle.booking.service.impl;

import com.cloudinary.Cloudinary;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.service.ImageStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class CloudinaryImageStorageServiceImpl implements ImageStorageService {

    private static final Set<String> ALLOWED_MIME_TYPES = Set.of("image/jpeg", "image/png");

    private final Cloudinary cloudinary;

    @Value("${cloudinary.folder:vehicle-booking/cars}")
    private String cloudinaryFolder;

    @Override
    public StoredImage uploadCarImage(MultipartFile file, Long carId) {
        validateUploadInput(file, carId);

        String targetFolder = buildTargetFolder(carId);
        Map<String, Object> options = new HashMap<>();
        options.put("folder", targetFolder);
        options.put("resource_type", "image");

        try {
            Map<?, ?> result = cloudinary.uploader().upload(file.getBytes(), options);
            String url = extractUrl(result);
            String publicId = toNullableString(result.get("public_id"));
            String format = toNullableString(result.get("format"));
            Long bytes = toNullableLong(result.get("bytes"));

            return new StoredImage(url, publicId, format, bytes);
        } catch (IOException ex) {
            throw new AppException(ErrorCode.CAR_IMAGE_UPLOAD_FAILED);
        }
    }

    @Override
    public void deleteByPublicId(String publicId) {
        if (publicId == null || publicId.isBlank()) {
            return;
        }

        Map<String, Object> options = new HashMap<>();
        options.put("resource_type", "image");
        options.put("invalidate", true);

        try {
            cloudinary.uploader().destroy(publicId, options);
        } catch (IOException ex) {
            throw new AppException(ErrorCode.CAR_IMAGE_UPLOAD_FAILED);
        }
    }

    private void validateUploadInput(MultipartFile file, Long carId) {
        if (carId == null || file == null || file.isEmpty()) {
            throw new AppException(ErrorCode.COMMON_BAD_REQUEST);
        }

        String mimeType = normalizeMimeType(file.getContentType());
        if (!ALLOWED_MIME_TYPES.contains(mimeType)) {
            throw new AppException(ErrorCode.CAR_IMAGE_INVALID_FILE_TYPE);
        }
    }

    private String normalizeMimeType(String mimeType) {
        if (mimeType == null) {
            return "";
        }
        int separatorIndex = mimeType.indexOf(';');
        String normalized = separatorIndex >= 0 ? mimeType.substring(0, separatorIndex) : mimeType;
        return normalized.trim().toLowerCase(Locale.ROOT);
    }

    private String buildTargetFolder(Long carId) {
        String folder = cloudinaryFolder == null ? "" : cloudinaryFolder.trim();
        if (folder.isEmpty()) {
            folder = "vehicle-booking/cars";
        }
        return folder + "/" + carId;
    }

    private String extractUrl(Map<?, ?> result) {
        String secureUrl = toNullableString(result.get("secure_url"));
        if (secureUrl != null && !secureUrl.isBlank()) {
            return secureUrl;
        }
        return toNullableString(result.get("url"));
    }

    private String toNullableString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private Long toNullableLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.longValue();
        }
        try {
            return Long.parseLong(String.valueOf(value));
        } catch (NumberFormatException ex) {
            return null;
        }
    }
}

