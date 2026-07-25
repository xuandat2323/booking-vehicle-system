package vehicle.booking.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

/**
 * GeminiService — parse câu hỏi → filter JSON + viết câu trả lời ngắn gọn.
 */
@Slf4j
@Service
public class GeminiService {

    private static final String GEMINI_API_URL =
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

    @Value("${gemini.api-key:}")
    private String apiKey;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    public GeminiService(RestTemplate restTemplate, ObjectMapper objectMapper) {
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
    }

    public boolean isAvailable() {
        return apiKey != null && !apiKey.isBlank();
    }

    public String generateContent(String systemInstruction, String userMessage) {
        if (!isAvailable()) {
            log.warn("Gemini API key chưa được cấu hình");
            return null;
        }

        try {
            String url = GEMINI_API_URL + "?key=" + apiKey;

            Map<String, Object> body = Map.of(
                    "system_instruction", Map.of(
                            "parts", List.of(Map.of("text", systemInstruction))
                    ),
                    "contents", List.of(
                            Map.of("parts", List.of(Map.of("text", userMessage)))
                    ),
                    "generationConfig", Map.of(
                            "temperature", 0.2,
                            "maxOutputTokens", 700,
                            "responseMimeType", "application/json"
                    )
            );

            // formatResponse cần text tự do — dùng overload không ép JSON
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);

            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, request, String.class);

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                JsonNode root = objectMapper.readTree(response.getBody());
                JsonNode candidates = root.path("candidates");
                if (candidates.isArray() && !candidates.isEmpty()) {
                    return candidates.get(0).path("content").path("parts").get(0).path("text").asText();
                }
            }
        } catch (Exception e) {
            log.error("Lỗi gọi Gemini API: {}", e.getMessage(), e);
        }
        return null;
    }

    private String generatePlainText(String systemInstruction, String userMessage) {
        if (!isAvailable()) return null;
        try {
            String url = GEMINI_API_URL + "?key=" + apiKey;
            Map<String, Object> body = Map.of(
                    "system_instruction", Map.of(
                            "parts", List.of(Map.of("text", systemInstruction))
                    ),
                    "contents", List.of(
                            Map.of("parts", List.of(Map.of("text", userMessage)))
                    ),
                    "generationConfig", Map.of(
                            "temperature", 0.35,
                            "maxOutputTokens", 450
                    )
            );
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.POST, request, String.class);
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                JsonNode root = objectMapper.readTree(response.getBody());
                JsonNode candidates = root.path("candidates");
                if (candidates.isArray() && !candidates.isEmpty()) {
                    return candidates.get(0).path("content").path("parts").get(0).path("text").asText();
                }
            }
        } catch (Exception e) {
            log.error("Lỗi gọi Gemini API (plain): {}", e.getMessage(), e);
        }
        return null;
    }

    public String parseUserQueryToFilters(String userQuestion) {
        String systemPrompt = """
            Bạn là bộ parse filter cho GoRento (thuê xe tự lái tại 3 chi nhánh Hà Nội:
            GoRento Hoàn Kiếm, GoRento Cầu Giấy, GoRento Thanh Xuân).

            Trả về ĐÚNG 1 JSON object (không markdown) với các key tùy chọn:
            brand, name, minPrice, maxPrice, seats, fuelType, transmission, location, branchId

            Quy ước:
            - brand: VinFast|Toyota|Honda|Mazda|Hyundai|KIA|BMW|Mercedes-Benz|Audi|Ford|Mitsubishi|Suzuki
            - seats: số nguyên hoặc mảng số (vd 7 hoặc [7])
            - fuelType: GASOLINE|DIESEL|ELECTRIC|HYBRID
            - transmission: AUTOMATIC|MANUAL
            - Giá VND/ngày. "giá rẻ"/dưới 1tr → maxPrice 900000; tầm trung → 800000–1600000; cao cấp → minPrice 2000000
            - "Hoàn Kiếm|Tràng Tiền" → location "Hoàn Kiếm"; "Cầu Giấy|Duy Tân|Mỹ Đình" → "Cầu Giấy"; "Thanh Xuân|Nguyễn Trãi" → "Thanh Xuân"
            - Typo/slang tiếng Việt vẫn parse được (vd mec, vf8, 7cho)
            - Chỉ điền field chắc chắn suy ra được. Không bịa.
            - Không hiểu → {}
            """;

        return generateContent(systemPrompt, userQuestion);
    }

    public String formatResponse(String userQuestion, String carsJson, int totalFound) {
        String systemPrompt = """
            Bạn là trợ lý GoRento. Trả lời tiếng Việt, ngắn (tối đa 80 từ), thân thiện, không markdown đậm.
            - Chỉ dùng xe trong dữ liệu JSON.
            - Nêu 1–3 xe: tên đầy đủ (hãng + tên), giá đ/ngày, chi nhánh nếu có.
            - Kết thúc bằng lời mời chạm thẻ xe bên dưới để đặt.
            - Không bịa thông tin. Không liệt kê quá 3 xe trong text.
            """;

        String userMsg = String.format(
                "Câu hỏi: \"%s\"\nSố xe tìm thấy: %d\nJSON xe:\n%s",
                userQuestion, totalFound, carsJson
        );

        return generatePlainText(systemPrompt, userMsg);
    }
}
