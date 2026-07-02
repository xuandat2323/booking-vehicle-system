package vehicle.booking.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@Slf4j
@Service
@SuppressWarnings({"unchecked", "rawtypes"})
public class ViettelAiService {

    @Value("${viettelai.token}")
    private String token;

    private static final String BASE_URL = "https://viettelai.vn/ekyc";
    private final RestTemplate restTemplate = new RestTemplate();

    public Map<String, Object> ocrIdCard(MultipartFile file) {
        try {
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("image", resource(file));
            ResponseEntity<Map> resp = restTemplate.postForEntity(
                    BASE_URL + "/id_card?token=" + token, entity(body), Map.class);
            return resp.getBody() != null ? resp.getBody() : Map.of("code", 500);
        } catch (Exception e) {
            log.error("ViettelAI ocrIdCard error: {}", e.getMessage());
            return Map.of("code", 500, "en_message", e.getMessage());
        }
    }

    public Map<String, Object> spoofCheck(MultipartFile file) {
        try {
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("file", resource(file));
            ResponseEntity<Map> resp = restTemplate.postForEntity(
                    BASE_URL + "/id_spoof_check?token=" + token, entity(body), Map.class);
            return resp.getBody() != null ? resp.getBody() : Map.of("code", 500);
        } catch (Exception e) {
            log.error("ViettelAI spoofCheck error: {}", e.getMessage());
            return Map.of("code", 500, "en_message", e.getMessage());
        }
    }

    public Map<String, Object> faceMatch(MultipartFile face, MultipartFile idCard) {
        try {
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("face_image", resource(face));
            body.add("id_image", resource(idCard));
            ResponseEntity<Map> resp = restTemplate.postForEntity(
                    BASE_URL + "/face_matching?token=" + token, entity(body), Map.class);
            return resp.getBody() != null ? resp.getBody() : Map.of("code", 500);
        } catch (Exception e) {
            log.error("ViettelAI faceMatch error: {}", e.getMessage());
            return Map.of("code", 500, "en_message", e.getMessage());
        }
    }

    public Map<String, Object> livenessCheck(MultipartFile face) {
        try {
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("file", resource(face));
            ResponseEntity<Map> resp = restTemplate.postForEntity(
                    BASE_URL + "/liveness_check?token=" + token, entity(body), Map.class);
            return resp.getBody() != null ? resp.getBody() : Map.of("code", 500);
        } catch (Exception e) {
            log.error("ViettelAI livenessCheck error: {}", e.getMessage());
            return Map.of("code", 500, "en_message", e.getMessage());
        }
    }

    private ByteArrayResource resource(MultipartFile file) throws IOException {
        byte[] bytes = file.getBytes();
        String name = file.getOriginalFilename();
        return new ByteArrayResource(bytes) {
            @Override public String getFilename() { return name; }
        };
    }

    private HttpEntity<MultiValueMap<String, Object>> entity(MultiValueMap<String, Object> body) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        return new HttpEntity<>(body, headers);
    }
}
