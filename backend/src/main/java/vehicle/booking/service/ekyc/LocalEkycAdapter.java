package vehicle.booking.service.ekyc;

import lombok.extern.slf4j.Slf4j;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

/**
 * Calls the local Python eKYC microservice (EasyOCR + DeepFace + OpenCV).
 * Response format mirrors ViettelAI so VerificationController needs no changes.
 */
@Slf4j
public class LocalEkycAdapter implements EkycProvider {

    private final String serviceUrl;
    private final RestTemplate restTemplate;

    public LocalEkycAdapter(String serviceUrl, RestTemplate restTemplate) {
        this.serviceUrl = serviceUrl;
        this.restTemplate = restTemplate;
    }

    @Override
    public Map<String, Object> ocrIdCard(MultipartFile file) {
        return ocrDocument(file, null);
    }

    @Override
    public Map<String, Object> ocrDocument(MultipartFile file, String expectedDocType) {
        return post("/ocr", "file", file, expectedDocType);
    }

    @Override
    public Map<String, Object> spoofCheck(MultipartFile file) {
        // OCR-only server soft-pass spoof; gọi HTTP chỉ làm upload ảnh thêm 1 lần (~0.5–2s).
        // Bật lại khi chạy full main.py với spoof thật (DeepFace).
        return Map.of(
                "code", 200,
                "message", "spoof soft-pass (skip remote on local OCR)",
                "data", Map.of("is_fake", false, "is_spoof", false, "score", 0.0)
        );
    }

    @Override
    public Map<String, Object> faceMatch(MultipartFile face, MultipartFile idCard) {
        try {
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("face", resource(face));
            body.add("id_image", resource(idCard));
            ResponseEntity<Map<String, Object>> resp = restTemplate.exchange(
                    serviceUrl + "/face-match", HttpMethod.POST, entity(body),
                    new ParameterizedTypeReference<Map<String, Object>>() {});
            return resp.getBody() != null ? resp.getBody() : Map.of("code", 500);
        } catch (Exception e) {
            log.error("LocalEkyc faceMatch error: {}", e.getMessage());
            return Map.of("code", 500, "message", e.getMessage());
        }
    }

    @Override
    public Map<String, Object> livenessCheck(MultipartFile face) {
        return post("/liveness", "file", face, null);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private Map<String, Object> post(String path, String paramName, MultipartFile file, String docType) {
        try {
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add(paramName, resource(file));
            if (docType != null && !docType.isBlank()) {
                body.add("doc_type", docType);
            }
            ResponseEntity<Map<String, Object>> resp = restTemplate.exchange(
                    serviceUrl + path, HttpMethod.POST, entity(body),
                    new ParameterizedTypeReference<Map<String, Object>>() {});
            return resp.getBody() != null ? resp.getBody() : Map.of("code", 500);
        } catch (Exception e) {
            log.error("LocalEkyc {} error: {}", path, e.getMessage());
            return Map.of("code", 500, "message", e.getMessage());
        }
    }

    private ByteArrayResource resource(MultipartFile file) {
        try {
            byte[] bytes = file.getBytes();
            String name = file.getOriginalFilename() != null ? file.getOriginalFilename() : "image.jpg";
            return new ByteArrayResource(bytes) {
                @Override public String getFilename() { return name; }
            };
        } catch (Exception e) {
            throw new RuntimeException("Cannot read file bytes", e);
        }
    }

    private HttpEntity<MultiValueMap<String, Object>> entity(MultiValueMap<String, Object> body) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        return new HttpEntity<>(body, headers);
    }
}
