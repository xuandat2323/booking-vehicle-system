package vehicle.booking.service.ekyc;

import lombok.extern.slf4j.Slf4j;
import org.springframework.web.multipart.MultipartFile;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Built-in eKYC for local/dev. Accepts any non-empty image upload and returns
 * synthetic OCR / spoof / face / liveness payloads so the 5-step verification
 * flow can complete without ViettelAI or an external Python service.
 */
@Slf4j
public class MockEkycAdapter implements EkycProvider {

    @Override
    public Map<String, Object> ocrIdCard(MultipartFile file) {
        return ocrDocument(file, "cccd");
    }

    @Override
    public Map<String, Object> ocrDocument(MultipartFile file, String expectedDocType) {
        requireImage(file);
        Map<String, Object> data = new LinkedHashMap<>();
        String id = "079" + String.format("%09d", Math.abs(UUID.randomUUID().hashCode() % 1_000_000_000));
        data.put("id", id);
        data.put("name", "NGUYEN VAN A");
        data.put("birth_day", "01/01/1995");
        data.put("home", "Ha Noi, Viet Nam");
        data.put("issue_date", "15/08/2021");
        data.put("expiry", "01/01/2035");
        data.put("barcode", id);
        String type = expectedDocType == null ? "cccd" : expectedDocType.toLowerCase();
        if (type.startsWith("license")) {
            data.put("type", "B2");
            data.put("doc_type", "license");
        } else {
            data.put("doc_type", "cccd");
        }
        log.info("MockEkyc OCR ok type={} file={} size={}", type, safeName(file), file.getSize());
        return Map.of("code", 200, "message", "OCR mock success", "data", data);
    }

    @Override
    public Map<String, Object> spoofCheck(MultipartFile file) {
        requireImage(file);
        Map<String, Object> data = Map.of(
                "is_fake", false,
                "is_spoof", false,
                "score", 0.02
        );
        return Map.of("code", 200, "message", "Spoof check mock success", "data", data);
    }

    @Override
    public Map<String, Object> faceMatch(MultipartFile face, MultipartFile idCard) {
        requireImage(face);
        requireImage(idCard);
        Map<String, Object> data = Map.of(
                "similarity", 0.92,
                "score", 0.92
        );
        return Map.of("code", 200, "message", "Face match mock success", "data", data);
    }

    @Override
    public Map<String, Object> livenessCheck(MultipartFile face) {
        requireImage(face);
        Map<String, Object> data = Map.of(
                "is_live", true,
                "liveness_score", 0.95
        );
        return Map.of("code", 200, "message", "Liveness mock success", "data", data);
    }

    private void requireImage(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Ảnh upload trống");
        }
    }

    private String safeName(MultipartFile file) {
        return file.getOriginalFilename() != null ? file.getOriginalFilename() : "image";
    }
}
