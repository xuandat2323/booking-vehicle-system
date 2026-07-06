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
 * GeminiService — gọi Gemini API (gemini-2.0-flash) để:
 * 1. Parse câu hỏi tự nhiên → structured filter
 * 2. Trau chuốt câu trả lời tiếng Việt
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

    /**
     * Gửi prompt tới Gemini và trả về text response.
     */
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
                    "temperature", 0.3,
                    "maxOutputTokens", 1024
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
            log.error("Lỗi gọi Gemini API: {}", e.getMessage(), e);
        }
        return null;
    }

    /**
     * Parse câu hỏi tự nhiên của khách thành structured JSON filter.
     * Gemini sẽ hiểu các câu viết tắt, typo, slang.
     */
    public String parseUserQueryToFilters(String userQuestion) {
        String systemPrompt = """
            Bạn là AI assistant cho hệ thống thuê xe GoRento.
            Nhiệm vụ: Parse câu hỏi của khách hàng thành JSON filter để tìm xe phù hợp.
            
            Các trường filter có thể dùng:
            - brand: hãng xe (VinFast, Toyota, Honda, Mazda, Hyundai, KIA, BMW, Mercedes-Benz, Audi, Ford, Mitsubishi, Suzuki)
            - minPrice, maxPrice: khoảng giá (đơn vị VND/ngày)
            - seats: số chỗ ngồi (4, 5, 7, 8, 9)
            - fuelType: GASOLINE, DIESEL, ELECTRIC, HYBRID
            - transmission: AUTOMATIC, MANUAL
            - location: khu vực
            - name: tên xe cụ thể
            
            Quy tắc:
            - "giá rẻ" → maxPrice: 800000
            - "giá tầm trung" → minPrice: 800000, maxPrice: 1500000
            - "cao cấp" / "sang" → minPrice: 2000000
            - "7 chỗ" → seats: 7
            - "xe điện" → fuelType: ELECTRIC
            - "số tự động" / "AT" → transmission: AUTOMATIC
            - "số sàn" / "MT" → transmission: MANUAL
            
            CHỈ trả về JSON object, KHÔNG giải thích thêm.
            Nếu không parse được, trả về: {}
            """;

        return generateContent(systemPrompt, userQuestion);
    }

    /**
     * Trau chuốt câu trả lời dựa trên kết quả tìm xe.
     */
    public String formatResponse(String userQuestion, String carsJson, int totalFound) {
        String systemPrompt = """
            Bạn là trợ lý ảo thân thiện của GoRento — hệ thống thuê xe tự lái.
            Trả lời bằng tiếng Việt, ngắn gọn, thân thiện. Dùng emoji phù hợp.
            
            Quy tắc:
            - Nếu tìm thấy xe: tóm tắt các xe phù hợp nhất (tên, giá, đặc điểm nổi bật)
            - Nếu không tìm thấy: gợi ý thử lại với tiêu chí khác
            - Luôn khuyến khích khách đặt xe
            - Giá hiển thị dạng "XXX.XXX đ/ngày"
            - KHÔNG bịa thông tin xe không có trong dữ liệu
            - Giới hạn 200 từ
            """;

        String userMsg = String.format(
            "Câu hỏi khách: \"%s\"\nTìm thấy %d xe.\nDữ liệu xe:\n%s",
            userQuestion, totalFound, carsJson
        );

        return generateContent(systemPrompt, userMsg);
    }
}
