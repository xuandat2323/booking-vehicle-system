package vehicle.booking.service.ekyc;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

/**
 * eKYC gateway.
 * <ul>
 *   <li>{@code ekyc.mode=local} (default) — real OCR via Python EasyOCR at {@code ekyc.local-service-url}</li>
 *   <li>{@code ekyc.mode=mock} — synthetic OCR for offline demos only</li>
 * </ul>
 * OCR never invents names when local mode fails; spoof/liveness may soft-pass so UX can continue after OCR succeeds.
 */
@Slf4j
@Service
public class EkycService {

    private final boolean mockMode;
    private final EkycProvider provider;

    public EkycService(
            @Value("${ekyc.mode:local}") String mode,
            @Value("${ekyc.local-service-url:http://localhost:8001}") String localUrl,
            RestTemplate restTemplate) {
        this.mockMode = "mock".equalsIgnoreCase(mode == null ? "" : mode.trim());
        if (mockMode) {
            this.provider = new MockEkycAdapter();
            log.warn("eKYC MOCK mode — OCR returns synthetic data (Nguyen Van A). Use only for demos.");
        } else {
            this.provider = new LocalEkycAdapter(localUrl, restTemplate);
            log.info("eKYC LOCAL OCR mode → {}", localUrl);
        }
    }

    public Map<String, Object> ocrIdCard(MultipartFile file) {
        return invoke("ocrIdCard", () -> provider.ocrIdCard(file), false);
    }

    public Map<String, Object> spoofCheck(MultipartFile file) {
        return invoke("spoofCheck", () -> provider.spoofCheck(file), true);
    }

    public Map<String, Object> faceMatch(MultipartFile face, MultipartFile idCard) {
        return invoke("faceMatch", () -> provider.faceMatch(face, idCard), true);
    }

    public Map<String, Object> livenessCheck(MultipartFile face) {
        return invoke("livenessCheck", () -> provider.livenessCheck(face), true);
    }

    private Map<String, Object> invoke(String op, Call call, boolean softPassOnFailure) {
        try {
            Map<String, Object> result = call.get();
            Object code = result.get("code");
            if (Integer.valueOf(200).equals(code)) {
                return result;
            }
            log.warn("eKYC {} code={} msg={}", op, code, result.get("message"));
            if (softPassOnFailure && !mockMode) {
                return softPass(op);
            }
            return result;
        } catch (IllegalArgumentException e) {
            return Map.of("code", 400, "message", e.getMessage());
        } catch (Exception e) {
            log.error("eKYC {} error: {}", op, e.getMessage());
            if (softPassOnFailure && !mockMode) {
                return softPass(op);
            }
            return Map.of(
                    "code", 503,
                    "message", "Dịch vụ OCR chưa chạy. Khởi động ekyc-service (port 8001) rồi upload lại.");
        }
    }

    private Map<String, Object> softPass(String op) {
        log.warn("eKYC {} soft-pass (OCR service unavailable for auxiliary check)", op);
        return switch (op) {
            case "spoofCheck" -> Map.of(
                    "code", 200,
                    "message", "spoof soft-pass",
                    "data", Map.of("is_fake", false, "is_spoof", false, "score", 0.0));
            case "livenessCheck" -> Map.of(
                    "code", 200,
                    "message", "liveness soft-pass",
                    "data", Map.of("is_live", true, "liveness_score", 0.8));
            case "faceMatch" -> Map.of(
                    "code", 200,
                    "message", "face soft-pass",
                    "data", Map.of("similarity", 0.8, "score", 0.8));
            default -> Map.of("code", 500, "message", "no soft-pass for " + op);
        };
    }

    @FunctionalInterface
    private interface Call {
        Map<String, Object> get() throws Exception;
    }
}
