package vehicle.booking.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import vehicle.booking.dto.response.CarSummaryResponse;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

import java.math.BigDecimal;
import java.util.*;

/**
 * ChatbotService — Xử lý câu hỏi từ user:
 * 1. Dùng Gemini parse câu hỏi tự nhiên → filter
 * 2. Query DB tìm xe
 * 3. Dùng Gemini trau chuốt câu trả lời
 * 4. Fallback keyword matching nếu Gemini không khả dụng
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatbotService {

    private final GeminiService geminiService;
    private final CarService carService;
    private final ObjectMapper objectMapper;

    public Map<String, Object> processQuestion(String question) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("question", question);

        try {
            // Step 1: Parse question → filters
            Map<String, Object> filters;
            if (geminiService.isAvailable()) {
                filters = parseWithGemini(question);
            } else {
                filters = parseWithKeywords(question);
            }
            result.put("filters", filters);

            // Step 2: Query cars based on filters
            List<CarSummaryResponse> cars = searchCarsWithFilters(filters);
            result.put("cars", cars);
            result.put("totalFound", cars.size());

            // Step 3: Generate friendly response
            String answer;
            if (geminiService.isAvailable()) {
                String carsJson = objectMapper.writeValueAsString(
                    cars.stream().limit(5).map(c -> Map.of(
                        "name", c.name(),
                        "brand", c.brand(),
                        "price", c.pricePerDay().toString(),
                        "seats", c.seats(),
                        "location", Objects.toString(c.location(), "")
                    )).toList()
                );
                answer = geminiService.formatResponse(question, carsJson, cars.size());
                if (answer == null) {
                    answer = buildFallbackAnswer(question, cars);
                }
            } else {
                answer = buildFallbackAnswer(question, cars);
            }
            result.put("answer", answer);

        } catch (Exception e) {
            log.error("Chatbot processing error: {}", e.getMessage(), e);
            result.put("answer", "Xin lỗi, tôi gặp lỗi khi xử lý câu hỏi của bạn. Vui lòng thử lại! 🙏");
            result.put("cars", Collections.emptyList());
            result.put("totalFound", 0);
        }

        return result;
    }

    private Map<String, Object> parseWithGemini(String question) {
        try {
            String filtersJson = geminiService.parseUserQueryToFilters(question);
            if (filtersJson != null) {
                // Strip markdown code fences if present
                filtersJson = filtersJson.trim();
                if (filtersJson.startsWith("```")) {
                    filtersJson = filtersJson.replaceAll("^```(?:json)?\\s*", "").replaceAll("\\s*```$", "");
                }
                JsonNode node = objectMapper.readTree(filtersJson);
                Map<String, Object> filters = new LinkedHashMap<>();
                node.fields().forEachRemaining(entry -> {
                    JsonNode value = entry.getValue();
                    if (value.isTextual()) filters.put(entry.getKey(), value.asText());
                    else if (value.isNumber()) filters.put(entry.getKey(), value.numberValue());
                    else if (value.isArray()) {
                        List<Object> list = new ArrayList<>();
                        value.forEach(v -> {
                            if (v.isNumber()) list.add(v.numberValue());
                            else list.add(v.asText());
                        });
                        filters.put(entry.getKey(), list);
                    }
                });
                return filters;
            }
        } catch (Exception e) {
            log.warn("Gemini parse failed, falling back to keywords: {}", e.getMessage());
        }
        return parseWithKeywords(question);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseWithKeywords(String question) {
        Map<String, Object> filters = new LinkedHashMap<>();
        String q = question.toLowerCase();

        // Brand detection
        Map<String, String> brandMap = Map.ofEntries(
            Map.entry("vinfast", "VinFast"), Map.entry("toyota", "Toyota"),
            Map.entry("honda", "Honda"), Map.entry("mazda", "Mazda"),
            Map.entry("hyundai", "Hyundai"), Map.entry("kia", "KIA"),
            Map.entry("bmw", "BMW"), Map.entry("mercedes", "Mercedes-Benz"),
            Map.entry("audi", "Audi"), Map.entry("ford", "Ford"),
            Map.entry("mitsubishi", "Mitsubishi"), Map.entry("suzuki", "Suzuki")
        );
        for (var entry : brandMap.entrySet()) {
            if (q.contains(entry.getKey())) {
                filters.put("brand", entry.getValue());
                break;
            }
        }

        // Seats
        if (q.contains("7 chỗ") || q.contains("7 cho") || q.contains("7ch")) {
            filters.put("seats", List.of(7));
        } else if (q.contains("5 chỗ") || q.contains("5 cho") || q.contains("5ch")) {
            filters.put("seats", List.of(5));
        } else if (q.contains("4 chỗ") || q.contains("4 cho") || q.contains("4ch")) {
            filters.put("seats", List.of(4));
        }

        // Price
        if (q.contains("giá rẻ") || q.contains("gia re") || q.contains("rẻ") || q.contains("tiết kiệm")) {
            filters.put("maxPrice", 800000);
        } else if (q.contains("cao cấp") || q.contains("sang") || q.contains("luxury") || q.contains("hạng sang")) {
            filters.put("minPrice", 2000000);
        } else if (q.contains("tầm trung") || q.contains("vừa")) {
            filters.put("minPrice", 800000);
            filters.put("maxPrice", 1500000);
        }

        // Fuel type
        if (q.contains("điện") || q.contains("dien") || q.contains("electric")) {
            filters.put("fuelType", "ELECTRIC");
        } else if (q.contains("hybrid")) {
            filters.put("fuelType", "HYBRID");
        } else if (q.contains("diesel") || q.contains("dầu")) {
            filters.put("fuelType", "DIESEL");
        }

        // Transmission
        if (q.contains("số sàn") || q.contains("so san") || q.contains("mt") || q.contains("manual")) {
            filters.put("transmission", "MANUAL");
        } else if (q.contains("số tự động") || q.contains("at") || q.contains("automatic")) {
            filters.put("transmission", "AUTOMATIC");
        }

        return filters;
    }

    @SuppressWarnings("unchecked")
    private List<CarSummaryResponse> searchCarsWithFilters(Map<String, Object> filters) {
        String brand = (String) filters.get("brand");
        String name = (String) filters.get("name");
        String location = (String) filters.get("location");

        Transmission transmission = null;
        if (filters.get("transmission") != null) {
            try { transmission = Transmission.valueOf(filters.get("transmission").toString()); } catch (Exception ignored) {}
        }

        FuelType fuelType = null;
        if (filters.get("fuelType") != null) {
            try { fuelType = FuelType.valueOf(filters.get("fuelType").toString()); } catch (Exception ignored) {}
        }

        BigDecimal minPrice = filters.get("minPrice") != null
                ? new BigDecimal(filters.get("minPrice").toString()) : null;
        BigDecimal maxPrice = filters.get("maxPrice") != null
                ? new BigDecimal(filters.get("maxPrice").toString()) : null;

        List<Integer> seats = null;
        if (filters.get("seats") != null) {
            Object seatsObj = filters.get("seats");
            if (seatsObj instanceof List<?> list) {
                seats = list.stream().map(s -> ((Number) s).intValue()).toList();
            } else if (seatsObj instanceof Number num) {
                seats = List.of(num.intValue());
            }
        }

        Long branchId = filters.get("branchId") != null
                ? Long.valueOf(filters.get("branchId").toString()) : null;

        Page<CarSummaryResponse> page = carService.searchCars(
                true, brand, name, location,
                transmission, fuelType,
                minPrice, maxPrice,
                seats, branchId,
                PageRequest.of(0, 10)
        );
        return page.getContent();
    }

    private String buildFallbackAnswer(String question, List<CarSummaryResponse> cars) {
        if (cars.isEmpty()) {
            return "Xin lỗi, tôi không tìm thấy xe phù hợp với yêu cầu của bạn. 😅\n" +
                   "Bạn có thể thử:\n" +
                   "• Mở rộng khoảng giá\n" +
                   "• Thử loại xe khác\n" +
                   "• Xem tất cả xe có sẵn trong mục \"Tìm xe\"";
        }

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("Tôi tìm thấy %d xe phù hợp! 🚗✨\n\n", cars.size()));
        int limit = Math.min(cars.size(), 3);
        for (int i = 0; i < limit; i++) {
            CarSummaryResponse car = cars.get(i);
            sb.append(String.format("🔹 **%s** — %s đ/ngày\n",
                    car.name(),
                    String.format("%,.0f", car.pricePerDay())));
            sb.append(String.format("   %d chỗ | %s\n\n",
                    car.seats(),
                    Objects.toString(car.location(), "")));
        }
        if (cars.size() > 3) {
            sb.append(String.format("...và %d xe khác.\n", cars.size() - 3));
        }
        sb.append("\nBấm vào xe để xem chi tiết và đặt ngay nhé! 🎉");
        return sb.toString();
    }
}
