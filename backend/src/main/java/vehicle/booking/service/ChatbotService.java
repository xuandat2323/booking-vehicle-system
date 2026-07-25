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
import vehicle.booking.exception.AppException;

import java.math.BigDecimal;
import java.text.Normalizer;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Chatbot tìm xe: parse câu hỏi (Gemini + keyword), tìm/nới filter dần, trả lời gọn + gợi ý.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatbotService {

    private final GeminiService geminiService;
    private final CarService carService;
    private final ObjectMapper objectMapper;

    private static final Pattern PRICE_UNDER = Pattern.compile(
            "(?:duoi|dưới|<|<=|toi da|tối đa|max)\\s*(\\d+(?:[.,]\\d+)?)\\s*(trieu|tr|k|ngan|nghìn)?",
            Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
    private static final Pattern PRICE_FROM = Pattern.compile(
            "(?:tu|từ|>=|>|toi thieu|tối thiểu|min)\\s*(\\d+(?:[.,]\\d+)?)\\s*(trieu|tr|k|ngan|nghìn)?",
            Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);

    public Map<String, Object> processQuestion(String question) {
        Map<String, Object> result = new LinkedHashMap<>();
        String q = question == null ? "" : question.trim();
        result.put("question", q);

        try {
            Map<String, Object> keywordFilters = parseWithKeywords(q);
            Map<String, Object> filters = new LinkedHashMap<>(keywordFilters);

            if (geminiService.isAvailable()) {
                Map<String, Object> geminiFilters = parseWithGemini(q);
                // Keyword làm nền; Gemini bổ sung / ghi đè khi có giá trị rõ
                mergeFilters(filters, geminiFilters);
            }
            sanitizeFilters(filters);
            result.put("filters", filters);

            SearchOutcome outcome = searchWithRelaxation(filters);
            List<CarSummaryResponse> cars = outcome.cars();
            result.put("cars", cars);
            result.put("totalFound", cars.size());
            result.put("relaxed", outcome.relaxed());
            result.put("suggestions", buildSuggestions(filters, cars));

            String answer;
            if (geminiService.isAvailable() && !cars.isEmpty()) {
                String carsJson = objectMapper.writeValueAsString(
                        cars.stream().limit(5).map(this::carBrief).toList()
                );
                answer = geminiService.formatResponse(q, carsJson, cars.size());
                if (answer == null || answer.isBlank()) {
                    answer = buildFallbackAnswer(q, cars, outcome.relaxed());
                }
            } else {
                answer = buildFallbackAnswer(q, cars, outcome.relaxed());
            }
            result.put("answer", stripMarkdownNoise(answer));

        } catch (AppException e) {
            log.info("Chatbot filter validation failed: {}", e.getResolvedMessage());
            result.put("answer", "Mình chưa hiểu rõ yêu cầu đó. Thử hỏi theo hãng (Toyota, VinFast…), "
                    + "số chỗ (5/7 chỗ), giá (dưới 1 triệu), hoặc chi nhánh (Hoàn Kiếm, Cầu Giấy, Thanh Xuân) nhé.");
            result.put("cars", Collections.emptyList());
            result.put("totalFound", 0);
            result.put("suggestions", List.of("Xe 7 chỗ", "VinFast điện", "Giá dưới 1 triệu", "Chi nhánh Hoàn Kiếm"));
        } catch (Exception e) {
            log.error("Chatbot processing error: {}", e.getMessage(), e);
            result.put("answer", "Xin lỗi, có lỗi khi tìm xe. Bạn thử lại giúp mình nhé.");
            result.put("cars", Collections.emptyList());
            result.put("totalFound", 0);
            result.put("suggestions", List.of("Toyota tầm trung", "Xe 7 chỗ giá rẻ", "Xe điện"));
        }

        return result;
    }

    private Map<String, Object> carBrief(CarSummaryResponse c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.id());
        m.put("title", displayTitle(c.brand(), c.name()));
        m.put("brand", c.brand());
        m.put("name", c.name());
        m.put("price", c.pricePerDay() != null ? c.pricePerDay().toPlainString() : "0");
        m.put("seats", c.seats());
        m.put("branch", Objects.toString(c.branchName(), ""));
        m.put("location", Objects.toString(c.location(), ""));
        m.put("fuel", ""); // summary DTO không có fuel — bỏ trống
        return m;
    }

    private static String displayTitle(String brand, String name) {
        String b = brand == null ? "" : brand.trim();
        String n = name == null ? "" : name.trim();
        if (n.isEmpty()) return b;
        if (b.isEmpty()) return n;
        if (n.toLowerCase(Locale.ROOT).contains(b.toLowerCase(Locale.ROOT))) return n;
        return b + " " + n;
    }

    private void mergeFilters(Map<String, Object> base, Map<String, Object> overlay) {
        if (overlay == null) return;
        for (var e : overlay.entrySet()) {
            if (e.getValue() == null) continue;
            if (e.getValue() instanceof String s && s.isBlank()) continue;
            if (e.getValue() instanceof List<?> list && list.isEmpty()) continue;
            base.put(e.getKey(), e.getValue());
        }
    }

    private void sanitizeFilters(Map<String, Object> filters) {
        // Bỏ location quá rộng / nhiễu
        Object loc = filters.get("location");
        if (loc instanceof String s) {
            String n = normalize(s);
            if (n.isBlank() || n.equals("ha noi") || n.equals("vietnam") || n.equals("vn")) {
                filters.remove("location");
            }
        }
        // seats: luôn list Integer
        Object seats = filters.get("seats");
        if (seats instanceof Number num) {
            filters.put("seats", List.of(num.intValue()));
        }
    }

    private Map<String, Object> parseWithGemini(String question) {
        try {
            String filtersJson = geminiService.parseUserQueryToFilters(question);
            if (filtersJson != null) {
                filtersJson = filtersJson.trim();
                if (filtersJson.startsWith("```")) {
                    filtersJson = filtersJson.replaceAll("^```(?:json)?\\s*", "").replaceAll("\\s*```$", "");
                }
                JsonNode node = objectMapper.readTree(filtersJson);
                Map<String, Object> filters = new LinkedHashMap<>();
                node.fields().forEachRemaining(entry -> {
                    JsonNode value = entry.getValue();
                    if (value == null || value.isNull()) return;
                    if (value.isTextual()) {
                        String t = value.asText();
                        if (!t.isBlank() && !"null".equalsIgnoreCase(t)) filters.put(entry.getKey(), t);
                    } else if (value.isNumber()) {
                        filters.put(entry.getKey(), value.numberValue());
                    } else if (value.isArray()) {
                        List<Object> list = new ArrayList<>();
                        value.forEach(v -> {
                            if (v.isNumber()) list.add(v.numberValue());
                            else if (v.isTextual()) list.add(v.asText());
                        });
                        if (!list.isEmpty()) filters.put(entry.getKey(), list);
                    }
                });
                return filters;
            }
        } catch (Exception e) {
            log.warn("Gemini parse failed, using keywords only: {}", e.getMessage());
        }
        return Collections.emptyMap();
    }

    private Map<String, Object> parseWithKeywords(String question) {
        Map<String, Object> filters = new LinkedHashMap<>();
        String q = normalize(question);

        Map<String, String> brandMap = new LinkedHashMap<>();
        brandMap.put("mercedes benz", "Mercedes-Benz");
        brandMap.put("mercedes-benz", "Mercedes-Benz");
        brandMap.put("mercedes", "Mercedes-Benz");
        brandMap.put("mec", "Mercedes-Benz");
        brandMap.put("benz", "Mercedes-Benz");
        brandMap.put("vinfast", "VinFast");
        brandMap.put("vin fast", "VinFast");
        brandMap.put("toyota", "Toyota");
        brandMap.put("honda", "Honda");
        brandMap.put("mazda", "Mazda");
        brandMap.put("hyundai", "Hyundai");
        brandMap.put("kia", "KIA");
        brandMap.put("bmw", "BMW");
        brandMap.put("audi", "Audi");
        brandMap.put("ford", "Ford");
        brandMap.put("mitsubishi", "Mitsubishi");
        brandMap.put("suzuki", "Suzuki");
        for (var entry : brandMap.entrySet()) {
            if (q.contains(entry.getKey())) {
                filters.put("brand", entry.getValue());
                break;
            }
        }

        // Model / tên xe cụ thể
        Map<String, String> modelHints = Map.ofEntries(
                Map.entry("vf8", "VF8"), Map.entry("vf9", "VF9"), Map.entry("vf6", "VF6"),
                Map.entry("camry", "Camry"), Map.entry("c200", "C200"), Map.entry("cx-5", "CX-5"),
                Map.entry("cx5", "CX-5"), Map.entry("cr-v", "CR-V"), Map.entry("crv", "CR-V"),
                Map.entry("elantra", "Elantra"), Map.entry("santa fe", "Santa Fe"),
                Map.entry("fortuner", "Fortuner"), Map.entry("ranger", "Ranger"),
                Map.entry("xpander", "Xpander"), Map.entry("sorento", "Sorento"),
                Map.entry("320i", "320i"), Map.entry("q5", "Q5")
        );
        for (var entry : modelHints.entrySet()) {
            if (q.contains(entry.getKey())) {
                filters.put("name", entry.getValue());
                break;
            }
        }

        if (q.contains("7 cho") || q.contains("7cho") || q.matches(".*\\b7\\b.*cho.*")) {
            filters.put("seats", List.of(7));
        } else if (q.contains("5 cho") || q.contains("5cho") || q.matches(".*\\b5\\b.*cho.*")) {
            filters.put("seats", List.of(5));
        } else if (q.contains("4 cho") || q.contains("4cho")) {
            filters.put("seats", List.of(4));
        } else if (q.contains("gia dinh") || q.contains("dong nguoi") || q.contains("suv")) {
            filters.put("seats", List.of(7));
        }

        if (q.contains("gia re") || q.contains("re nhat") || q.contains("tiet kiem") || q.contains("binh dan")) {
            filters.put("maxPrice", 900000);
            filters.put("sort", "priceAsc");
        } else if (q.contains("cao cap") || q.contains("hang sang") || q.contains("luxury") || q.contains("sang trong")) {
            filters.put("minPrice", 2000000);
            filters.put("sort", "priceDesc");
        } else if (q.contains("tam trung") || q.contains("vua phai") || q.contains("trung cap")) {
            filters.put("minPrice", 800000);
            filters.put("maxPrice", 1600000);
        }

        applyPricePatterns(q, filters);

        if (q.contains("dien") || q.contains("electric") || q.contains("ev ")) {
            filters.put("fuelType", "ELECTRIC");
        } else if (q.contains("hybrid")) {
            filters.put("fuelType", "HYBRID");
        } else if (q.contains("diesel") || q.contains("dau ")) {
            filters.put("fuelType", "DIESEL");
        }

        if (q.contains("so san") || q.contains("manual") || q.matches(".*\\bmt\\b.*")) {
            filters.put("transmission", "MANUAL");
        } else if (q.contains("so tu dong") || q.contains("automatic") || q.matches(".*\\bat\\b.*")) {
            filters.put("transmission", "AUTOMATIC");
        }

        // Chi nhánh / khu vực (storefront)
        if (q.contains("hoan kiem") || q.contains("trang tien")) {
            filters.put("location", "Hoàn Kiếm");
        } else if (q.contains("cau giay") || q.contains("duy tan") || q.contains("my dinh") || q.contains("tu liem")) {
            filters.put("location", "Cầu Giấy");
        } else if (q.contains("thanh xuan") || q.contains("nguyen trai") || q.contains("ha dong")) {
            filters.put("location", "Thanh Xuân");
        }

        return filters;
    }

    private void applyPricePatterns(String q, Map<String, Object> filters) {
        Matcher under = PRICE_UNDER.matcher(q);
        if (under.find()) {
            BigDecimal v = parsePriceToken(under.group(1), under.group(2));
            if (v != null) filters.put("maxPrice", v);
        }
        Matcher from = PRICE_FROM.matcher(q);
        if (from.find()) {
            BigDecimal v = parsePriceToken(from.group(1), from.group(2));
            if (v != null) filters.put("minPrice", v);
        }
        // "1tr", "1.5 triệu/ngày"
        Matcher tr = Pattern.compile("(\\d+(?:[.,]\\d+)?)\\s*(trieu|tr)\\b").matcher(q);
        if (tr.find() && !filters.containsKey("maxPrice") && !filters.containsKey("minPrice")) {
            BigDecimal v = parsePriceToken(tr.group(1), tr.group(2));
            if (v != null) {
                filters.put("minPrice", v.multiply(new BigDecimal("0.7")));
                filters.put("maxPrice", v.multiply(new BigDecimal("1.3")));
            }
        }
    }

    private BigDecimal parsePriceToken(String num, String unit) {
        try {
            double n = Double.parseDouble(num.replace(',', '.'));
            String u = unit == null ? "" : normalize(unit);
            if (u.startsWith("tr")) return BigDecimal.valueOf(Math.round(n * 1_000_000L));
            if (u.startsWith("k") || u.contains("ngan") || u.contains("nghin")) {
                return BigDecimal.valueOf(Math.round(n * 1_000L));
            }
            // Số trần: < 100 coi như triệu, còn lại là VND
            if (n < 100) return BigDecimal.valueOf(Math.round(n * 1_000_000L));
            if (n < 100_000) return BigDecimal.valueOf(Math.round(n * 1_000L));
            return BigDecimal.valueOf(Math.round(n));
        } catch (Exception e) {
            return null;
        }
    }

    private record SearchOutcome(List<CarSummaryResponse> cars, boolean relaxed) {}

    private SearchOutcome searchWithRelaxation(Map<String, Object> filters) {
        List<CarSummaryResponse> cars = searchCarsWithFilters(filters);
        if (!cars.isEmpty()) {
            return new SearchOutcome(sortCars(cars, filters), false);
        }

        // Nới dần: name → location → fuel/transmission → seats → price band
        List<String> dropOrder = List.of("name", "location", "fuelType", "transmission", "seats", "minPrice", "maxPrice", "brand");
        Map<String, Object> relaxed = new LinkedHashMap<>(filters);
        for (String key : dropOrder) {
            if (!relaxed.containsKey(key)) continue;
            relaxed.remove(key);
            cars = searchCarsWithFilters(relaxed);
            if (!cars.isEmpty()) {
                return new SearchOutcome(sortCars(cars, filters), true);
            }
        }

        // Cuối cùng: mọi xe available
        cars = searchCarsWithFilters(Collections.emptyMap());
        return new SearchOutcome(sortCars(cars, filters), true);
    }

    private List<CarSummaryResponse> sortCars(List<CarSummaryResponse> cars, Map<String, Object> filters) {
        String sort = Objects.toString(filters.get("sort"), "");
        Comparator<CarSummaryResponse> cmp = Comparator.comparing(
                c -> c.pricePerDay() == null ? BigDecimal.ZERO : c.pricePerDay());
        if ("priceDesc".equals(sort)) {
            return cars.stream().sorted(cmp.reversed()).collect(Collectors.toList());
        }
        if ("priceAsc".equals(sort) || filters.containsKey("maxPrice")) {
            return cars.stream().sorted(cmp).collect(Collectors.toList());
        }
        // Ưu tiên đúng brand/name nếu có
        String brand = Objects.toString(filters.get("brand"), "").toLowerCase(Locale.ROOT);
        String name = Objects.toString(filters.get("name"), "").toLowerCase(Locale.ROOT);
        return cars.stream().sorted((a, b) -> {
            int sa = score(a, brand, name);
            int sb = score(b, brand, name);
            if (sa != sb) return Integer.compare(sb, sa);
            return cmp.compare(a, b);
        }).collect(Collectors.toList());
    }

    private int score(CarSummaryResponse c, String brand, String name) {
        int s = 0;
        String b = Objects.toString(c.brand(), "").toLowerCase(Locale.ROOT);
        String n = Objects.toString(c.name(), "").toLowerCase(Locale.ROOT);
        if (!brand.isEmpty() && b.contains(brand.toLowerCase(Locale.ROOT))) s += 5;
        if (!name.isEmpty() && (n.contains(name) || name.contains(n))) s += 8;
        return s;
    }

    @SuppressWarnings("unchecked")
    private List<CarSummaryResponse> searchCarsWithFilters(Map<String, Object> filters) {
        String brand = (String) filters.get("brand");
        String name = (String) filters.get("name");
        String location = (String) filters.get("location");

        Transmission transmission = null;
        if (filters.get("transmission") != null) {
            try {
                transmission = Transmission.valueOf(filters.get("transmission").toString());
            } catch (Exception ignored) {
            }
        }

        FuelType fuelType = null;
        if (filters.get("fuelType") != null) {
            try {
                fuelType = FuelType.valueOf(filters.get("fuelType").toString());
            } catch (Exception ignored) {
            }
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
                PageRequest.of(0, 12)
        );
        return new ArrayList<>(page.getContent());
    }

    private List<String> buildSuggestions(Map<String, Object> filters, List<CarSummaryResponse> cars) {
        LinkedHashSet<String> tips = new LinkedHashSet<>();
        if (cars.isEmpty() || Boolean.TRUE.equals(filters.get("_forceTips"))) {
            tips.add("Xe 7 chỗ");
            tips.add("VinFast điện");
            tips.add("Giá dưới 1 triệu");
            tips.add("Chi nhánh Cầu Giấy");
            return new ArrayList<>(tips);
        }
        if (!filters.containsKey("brand")) tips.add("Toyota");
        if (!filters.containsKey("seats")) tips.add("Xe 7 chỗ gia đình");
        if (!filters.containsKey("fuelType")) tips.add("Xe điện");
        if (!filters.containsKey("location")) tips.add("Gần Hoàn Kiếm");
        tips.add("Giá rẻ nhất");
        return tips.stream().limit(4).toList();
    }

    private String buildFallbackAnswer(String question, List<CarSummaryResponse> cars, boolean relaxed) {
        if (cars.isEmpty()) {
            return "Chưa thấy xe khớp yêu cầu.\n"
                    + "Thử: đổi khoảng giá, bỏ hãng cụ thể, hoặc chọn chi nhánh Hoàn Kiếm / Cầu Giấy / Thanh Xuân.";
        }

        StringBuilder sb = new StringBuilder();
        if (relaxed) {
            sb.append("Mình nới nhẹ tiêu chí để tìm gần đúng hơn — đây là các lựa chọn phù hợp:\n\n");
        } else {
            sb.append(String.format("Tìm thấy %d xe phù hợp:\n\n", cars.size()));
        }
        int limit = Math.min(cars.size(), 3);
        for (int i = 0; i < limit; i++) {
            CarSummaryResponse car = cars.get(i);
            sb.append(String.format("• %s — %s đ/ngày\n",
                    displayTitle(car.brand(), car.name()),
                    String.format("%,.0f", car.pricePerDay())));
            String branch = car.branchName() != null ? car.branchName() : Objects.toString(car.location(), "");
            sb.append(String.format("  %d chỗ%s\n",
                    car.seats() != null ? car.seats() : 0,
                    branch.isBlank() ? "" : " · " + branch));
        }
        if (cars.size() > 3) {
            sb.append(String.format("\n…và %d xe khác. Chạm thẻ bên dưới để xem chi tiết.", cars.size() - 3));
        } else {
            sb.append("\nChạm thẻ xe bên dưới để xem chi tiết và đặt.");
        }
        return sb.toString();
    }

    private static String stripMarkdownNoise(String text) {
        if (text == null) return "";
        return text
                .replace("**", "")
                .replace("__", "")
                .replaceAll("(?m)^#{1,6}\\s*", "")
                .trim();
    }

    private static String normalize(String input) {
        if (input == null) return "";
        String n = Normalizer.normalize(input, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd');
        return n.replaceAll("\\s+", " ").trim();
    }
}
