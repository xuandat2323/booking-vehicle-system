package vehicle.booking.service.impl;

import com.cloudinary.Cloudinary;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.service.ImageStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Slf4j
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

            if (url == null || url.isBlank()) {
                throw new AppException(ErrorCode.CAR_IMAGE_UPLOAD_FAILED, "Cloudinary không trả về URL ảnh.");
            }

            return new StoredImage(url, publicId, format, bytes);
        } catch (AppException ex) {
            throw ex;
        } catch (IOException ex) {
            log.error("Cloudinary IO error for car {}: {}", carId, ex.getMessage());
            throw new AppException(ErrorCode.CAR_IMAGE_UPLOAD_FAILED, summarizeCloudinaryError(ex));
        } catch (RuntimeException ex) {
            // SDK Cloudinary thường ném RuntimeException (sai/disabled key, mạng, quota...)
            log.error("Cloudinary upload failed for car {}: {}", carId, ex.getMessage());
            throw new AppException(ErrorCode.CAR_IMAGE_UPLOAD_FAILED, summarizeCloudinaryError(ex));
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
        } catch (IOException | RuntimeException ex) {
            log.warn("Cloudinary delete failed for {}: {}", publicId, ex.getMessage());
            throw new AppException(ErrorCode.CAR_IMAGE_UPLOAD_FAILED, summarizeCloudinaryError(ex));
        }
    }

    private String summarizeCloudinaryError(Throwable ex) {
        String raw = ex.getMessage() == null ? "" : ex.getMessage().toLowerCase(Locale.ROOT);
        if (raw.contains("disabled api_key") || raw.contains("invalid signature")
                || raw.contains("unknown api_key") || raw.contains("401")) {
            return "API key Cloudinary bị vô hiệu hoặc sai. Hãy tạo key mới trên Cloudinary Dashboard.";
        }
        if (raw.contains("rate limit") || raw.contains("limit") || raw.contains("quota")) {
            return "Tài khoản Cloudinary có thể đã hết hạn mức (quota/rate limit).";
        }
        if (raw.contains("timeout") || raw.contains("timed out") || raw.contains("connection")) {
            return "Không kết nối được Cloudinary. Kiểm tra mạng/firewall.";
        }
        String msg = ex.getMessage();
        if (msg == null || msg.isBlank()) {
            return "Vui lòng thử lại.";
        }
        // Giữ ngắn, không dump stack.
        return msg.length() > 160 ? msg.substring(0, 160) + "…" : msg;
    }

    private void validateUploadInput(MultipartFile file, Long carId) {
        if (carId == null || file == null || file.isEmpty()) {
            throw new AppException(ErrorCode.COMMON_BAD_REQUEST);
        }

        String mimeType = resolveMimeType(file);
        if (!ALLOWED_MIME_TYPES.contains(mimeType)) {
            throw new AppException(ErrorCode.CAR_IMAGE_INVALID_FILE_TYPE);
        }
    }

    /**
     * Dio/Android hay gửi part với content-type null hoặc application/octet-stream.
     * Khi đó suy luận từ tên file để không reject nhầm ảnh JPEG/PNG hợp lệ.
     */
    private String resolveMimeType(MultipartFile file) {
        String mimeType = normalizeMimeType(file.getContentType());
        if (ALLOWED_MIME_TYPES.contains(mimeType)) {
            return mimeType;
        }

        String filename = file.getOriginalFilename();
        if (filename == null) {
            return mimeType;
        }
        String lower = filename.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
            return "image/jpeg";
        }
        if (lower.endsWith(".png")) {
            return "image/png";
        }
        return mimeType;
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
