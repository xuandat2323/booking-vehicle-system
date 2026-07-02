package vehicle.booking.service.ekyc;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;
import vehicle.booking.service.ViettelAiService;

import java.util.Map;

/**
 * Tries ViettelAI first. Falls back to the local Python eKYC service
 * when ViettelAI returns a non-200 code or throws any exception.
 */
@Slf4j
@Service
public class EkycService {

    private final EkycProvider viettelAi;
    private final EkycProvider local;

    public EkycService(ViettelAiService viettelAiService,
                       @Value("${ekyc.local-service-url:http://localhost:8001}") String localUrl,
                       RestTemplate restTemplate) {
        this.viettelAi = new ViettelAiEkycAdapter(viettelAiService);
        this.local = new LocalEkycAdapter(localUrl, restTemplate);
    }

    public Map<String, Object> ocrIdCard(MultipartFile file) {
        return withFallback("ocrIdCard", () -> viettelAi.ocrIdCard(file), () -> local.ocrIdCard(file));
    }

    public Map<String, Object> spoofCheck(MultipartFile file) {
        return withFallback("spoofCheck", () -> viettelAi.spoofCheck(file), () -> local.spoofCheck(file));
    }

    public Map<String, Object> faceMatch(MultipartFile face, MultipartFile idCard) {
        return withFallback("faceMatch",
                () -> viettelAi.faceMatch(face, idCard),
                () -> local.faceMatch(face, idCard));
    }

    public Map<String, Object> livenessCheck(MultipartFile face) {
        return withFallback("livenessCheck", () -> viettelAi.livenessCheck(face), () -> local.livenessCheck(face));
    }

    // ── fallback logic ───────────────────────────────────────────────────────

    private Map<String, Object> withFallback(String op, Provider primary, Provider fallback) {
        try {
            Map<String, Object> result = primary.get();
            if (Integer.valueOf(200).equals(result.get("code"))) {
                return result;
            }
            log.warn("eKYC {} ViettelAI returned code={}, falling back to local", op, result.get("code"));
        } catch (Exception e) {
            log.warn("eKYC {} ViettelAI error: {}, falling back to local", op, e.getMessage());
        }

        try {
            Map<String, Object> result = fallback.get();
            log.info("eKYC {} local fallback code={}", op, result.get("code"));
            return result;
        } catch (Exception e) {
            log.error("eKYC {} local fallback also failed: {}", op, e.getMessage());
            return Map.of("code", 500, "message", "Cả hai dịch vụ eKYC đều không khả dụng");
        }
    }

    @FunctionalInterface
    private interface Provider {
        Map<String, Object> get() throws Exception;
    }
}
