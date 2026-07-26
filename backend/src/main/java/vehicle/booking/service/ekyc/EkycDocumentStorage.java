package vehicle.booking.service.ekyc;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Lưu ảnh CCCD mặt trước sau khi OCR thành công, để bước selfie chỉ cần gửi selfie
 * (không bắt user chọn lại ảnh giấy tờ).
 */
@Slf4j
@Service
public class EkycDocumentStorage {

    private final Path root;

    public EkycDocumentStorage(@Value("${ekyc.storage-dir:uploads/ekyc}") String storageDir) {
        this.root = Paths.get(storageDir).toAbsolutePath().normalize();
    }

    public void saveCccdFront(Long userId, MultipartFile image) {
        try {
            Path dir = userDir(userId);
            Files.createDirectories(dir);
            Path target = dir.resolve("cccd-front.jpg");
            // getBytes() an toàn hơn getInputStream() vì OCR/spoof có thể đã đọc stream.
            Files.write(target, image.getBytes());
            log.info("Saved CCCD front for user {} → {}", userId, target);
        } catch (IOException e) {
            log.error("Cannot save CCCD front for user {}: {}", userId, e.getMessage());
            throw new IllegalStateException("Không lưu được ảnh CCCD mặt trước", e);
        }
    }

    public MultipartFile loadCccdFront(Long userId) {
        Path target = userDir(userId).resolve("cccd-front.jpg");
        if (!Files.isRegularFile(target)) {
            return null;
        }
        try {
            byte[] bytes = Files.readAllBytes(target);
            return new BytesMultipartFile("idImage", "cccd-front.jpg", "image/jpeg", bytes);
        } catch (IOException e) {
            log.error("Cannot read CCCD front for user {}: {}", userId, e.getMessage());
            return null;
        }
    }

    public boolean hasCccdFront(Long userId) {
        return Files.isRegularFile(userDir(userId).resolve("cccd-front.jpg"));
    }

    private Path userDir(Long userId) {
        return root.resolve(String.valueOf(userId));
    }
}
