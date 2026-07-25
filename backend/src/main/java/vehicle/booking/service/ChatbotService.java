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

    // Các pattern giá chạy trên chuỗi ĐÃ normalize (bỏ dấu, đ→d, thường hoá).
    private static final String NUM = "(\\d+(?:[.,]\\d+)?)";
    private static final String UNIT = "\\s*(trieu|tr|k|ngan|nghin|dong|d|vnd)?";

    /** "từ 1 đến 2 triệu", "1 - 2 triệu", "1tr~2tr", "giữa 1 và 2 triệu". */
    private static final Pattern PRICE_RANGE = Pattern.compile(
            "(?:tu|giua|from)?\\s*" + NUM + UNIT
                    + "\\s*(?:den|toi|->|-|~|va)\\s*" + NUM + UNIT);
    /** "trên/hơn/lớn hơn/từ/tối thiểu 2 triệu". */
    private static final Pattern PRICE_MIN = Pattern.compile(
            "(?:tren|hon|lon hon|cao hon|>=|>|tu|toi thieu|it nhat|min)\\s*" + NUM + UNIT);
    /** "dưới/thấp hơn/ít hơn/không quá/tối đa 2 triệu". */
    private static final Pattern PRICE_MAX = Pattern.compile(
            "(?:duoi|thap hon|it hon|nho hon|re hon|khong qua|chua toi|toi da|<=|<|max)\\s*" + NUM + UNIT);
    /** "khoảng/tầm/xấp xỉ/cỡ giá 1 triệu" → dải ±20%. (Không nhận 'có'/'gần' đơn lẻ
     *  để tránh bắt nhầm "có 5 chỗ", "gần Hoàn Kiếm".) */
    private static final Pattern PRICE_AROUND = Pattern.compile(
            "(?:khoang|tam|xap xi|co gia|gia khoang)\\s*" + NUM + UNIT);
    /** "2 triệu" trơ trọi (không kèm từ khoá) → coi như khoảng giá gần đúng. */
    private static final Pattern PRICE_BARE = Pattern.compile(NUM + "\\s*(trieu|tr)\\b");

    public Map<String, Object> processQuestion(String question) {
        Map<String, Object> result = new LinkedHashMap<>();
        String q = question == null ? "" : question.trim();
        result.put("question", q);

        try {
            Map<String, Object> keywordFilters = parseWithKeywords(q);
            Map<String, Object> filters = new LinkedHashMap<>(keywordFilters);

            if (geminiService.isAvailable()) {
                Map<String, Object> geminiFilters = parseWithGemini(q);
                // Giá suy ra từ số cụ thể là chính xác nhất → không cho Gemini ghi đè.
                if (Boolean.TRUE.equals(filters.get("_priceLocked"))) {
                    geminiFilters.remove("minPrice");
                    geminiFilters.remove("maxPrice");
                }
                // Keyword làm nền; Gemini bổ sung / ghi đè phần còn lại khi có giá trị rõ.
                mergeFilters(filters, geminiFilters);
            }
            sanitizeFilters(filters);
            result.put("filters", filters);

            SearchOutcome outcome = searchWithRelaxation(filters);
            List<CarSummaryResponse> cars = outcome.cars();
            List<String> matchedLabels = describeCriteria(outcome.keptKeys(), filters);
            List<String> unmatchedLabels = describeCriteria(outcome.droppedKeys(), filters);

            result.put("cars", cars);
            result.put("totalFound", cars.size());
            result.put("relaxed", outcome.relaxed());
            result.put("matchedCriteria", matchedLabels);
            result.put("unmatchedCriteria", unmatchedLabels);
            result.put("suggestions", buildSuggestions(filters, cars));

            // Khi phải nới tiêu chí thì tự viết câu trả lời để không nói quá về độ khớp.
            String answer = null;
            if (geminiService.isAvailable() && !cars.isEmpty() && !outcome.relaxed()) {
                String carsJson = objectMapper.writeValueAsString(
                        cars.stream().limit(5).map(this::carBrief).toList()
                );
                answer = geminiService.formatResponse(q, carsJson, cars.size(), matchedLabels);
            }
            if (answer == null || answer.isBlank()) {
                answer = buildFallbackAnswer(cars, matchedLabels, unmatchedLabels);
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
        // Cờ nội bộ, không phải tiêu chí hiển thị cho khách.
        filters.remove("_priceLocked");
        filters.remove("_forceTips");
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
                Map.entry("santafe", "Santa Fe"), Map.entry("fortuner", "Fortuner"),
                Map.entry("ranger", "Ranger"), Map.entry("xpander", "Xpander"),
                Map.entry("sorento", "Sorento"), Map.entry("320i", "320i"),
                Map.entry("q5", "Q5"), Map.entry("k3", "K3"), Map.entry("ertiga", "Ertiga"),
                Map.entry("mazda2", "Mazda2"), Map.entry("mazda 2", "Mazda2")
        );
        for (var entry : modelHints.entrySet()) {
            if (q.contains(entry.getKey())) {
                filters.put("name", entry.getValue());
                break;
            }
        }

        // Số chỗ: bắt "N cho" tổng quát (2/4/5/7/9/16...), rồi tới gợi ý theo nhu cầu.
        Matcher seatM = Pattern.compile("(\\d+)\\s*cho").matcher(q);
        if (seatM.find()) {
            int n = Integer.parseInt(seatM.group(1));
            if (n >= 2 && n <= 16) filters.put("seats", List.of(n));
        } else if (q.contains("gia dinh") || q.contains("dong nguoi") || q.contains("7 nguoi")
                || q.contains("suv") || q.contains("da dung")) {
            filters.put("seats", List.of(7));
        } else if (q.contains("2 nguoi") || q.contains("cap doi") || q.contains("nho gon")
                || q.contains("mini")) {
            filters.put("seats", List.of(4));
        }

        // Tính từ về giá (chạy trước; số cụ thể sẽ ghi đè bên dưới).
        if (q.contains("re nhat") || q.contains("gia re") || q.contains("tiet kiem") || q.contains("binh dan")) {
            filters.put("maxPrice", 900000);
            filters.put("sort", "priceAsc");
        } else if (q.contains("cao cap") || q.contains("hang sang") || q.contains("luxury") || q.contains("sang trong")) {
            filters.put("minPrice", 2000000);
            filters.put("sort", "priceDesc");
        } else if (q.contains("tam trung") || q.contains("vua phai") || q.contains("trung cap")) {
            filters.put("minPrice", 800000);
            filters.put("maxPrice", 1600000);
        }
        if (q.contains("dat nhat") || q.contains("mac nhat")) filters.put("sort", "priceDesc");
        if (q.contains("re nhat")) filters.put("sort", "priceAsc");

        // Giá bằng số cụ thể — nguồn chính xác nhất, ghi đè tính từ ở trên.
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

    /**
     * Parse khoảng giá theo đúng ngữ nghĩa tiếng Việt. Đặt cờ _priceLocked để
     * Gemini không ghi đè giá đã hiểu chắc chắn từ số cụ thể.
     */
    private void applyPricePatterns(String q, Map<String, Object> filters) {
        // 1) Dải "từ X đến Y" — ưu tiên cao nhất, set cả hai đầu.
        Matcher range = PRICE_RANGE.matcher(q);
        if (range.find()) {
            String lowUnit = range.group(2);
            String highUnit = range.group(4);
            // Một đầu có đơn vị thì suy ra cho đầu còn lại (vd "từ 1 đến 2 triệu").
            if (isBlank(lowUnit) && !isBlank(highUnit)) lowUnit = highUnit;
            if (isBlank(highUnit) && !isBlank(lowUnit)) highUnit = lowUnit;
            BigDecimal lo = parsePriceToken(range.group(1), lowUnit);
            BigDecimal hi = parsePriceToken(range.group(3), highUnit);
            if (lo != null && hi != null) {
                if (lo.compareTo(hi) > 0) { BigDecimal t = lo; lo = hi; hi = t; }
                filters.put("minPrice", lo);
                filters.put("maxPrice", hi);
                filters.put("_priceLocked", true);
                return;
            }
        }

        // 2) Cận dưới / cận trên — có thể xuất hiện đồng thời trong 1 câu.
        boolean matched = false;
        Matcher min = PRICE_MIN.matcher(q);
        if (min.find()) {
            BigDecimal v = parsePriceToken(min.group(1), min.group(2));
            if (v != null) { filters.put("minPrice", v); matched = true; }
        }
        Matcher max = PRICE_MAX.matcher(q);
        if (max.find()) {
            BigDecimal v = parsePriceToken(max.group(1), max.group(2));
            if (v != null) { filters.put("maxPrice", v); matched = true; }
        }
        if (matched) {
            filters.put("_priceLocked", true);
            return;
        }

        // 3) "khoảng/tầm X" → dải ±20%.
        Matcher around = PRICE_AROUND.matcher(q);
        if (around.find()) {
            BigDecimal v = parsePriceToken(around.group(1), around.group(2));
            if (v != null) {
                filters.put("minPrice", v.multiply(new BigDecimal("0.8")).setScale(0, java.math.RoundingMode.HALF_UP));
                filters.put("maxPrice", v.multiply(new BigDecimal("1.2")).setScale(0, java.math.RoundingMode.HALF_UP));
                filters.put("_priceLocked", true);
                return;
            }
        }

        // 4) "X triệu" trơ (chưa có min/max từ tính từ) → dải gần đúng ±25%.
        if (!filters.containsKey("maxPrice") && !filters.containsKey("minPrice")) {
            Matcher bare = PRICE_BARE.matcher(q);
            if (bare.find()) {
                BigDecimal v = parsePriceToken(bare.group(1), bare.group(2));
                if (v != null) {
                    filters.put("minPrice", v.multiply(new BigDecimal("0.75")).setScale(0, java.math.RoundingMode.HALF_UP));
                    filters.put("maxPrice", v.multiply(new BigDecimal("1.25")).setScale(0, java.math.RoundingMode.HALF_UP));
                }
            }
        }
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
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

    private record SearchOutcome(
            List<CarSummaryResponse> cars,
            List<String> keptKeys,
            List<String> droppedKeys
    ) {
        boolean relaxed() {
            return !droppedKeys.isEmpty();
        }
    }

    /** Nhóm giá phải bỏ cùng nhau, nếu không "từ 1tr đến 2tr" bị lệch một đầu. */
    private static final List<String> PRICE_GROUP = List.of("minPrice", "maxPrice");

    /**
     * Thứ tự ưu tiên GIỮ tiêu chí: hãng và mẫu xe là ý định rõ nhất của khách,
     * khu vực dễ thay thế nhất nên bỏ trước.
     */
    private static final List<String> DROP_PRIORITY =
            List.of("location", "transmission", "fuelType", "price", "seats", "name", "brand");

    private static final int MAX_SEARCH_ATTEMPTS = 24;

    /**
     * Tìm theo AND đầy đủ trước. Nếu không có xe nào khớp hết thì bỏ CÀNG ÍT tiêu chí
     * càng tốt (thử bỏ 1 tiêu chí, rồi 2, …) để kết quả vẫn thỏa nhiều tiêu chí nhất,
     * và trả về đúng những tiêu chí đã phải bỏ để trả lời trung thực với khách.
     */
    private SearchOutcome searchWithRelaxation(Map<String, Object> filters) {
        List<String> active = activeCriteria(filters);

        List<CarSummaryResponse> cars = searchCarsWithFilters(filters);
        if (!cars.isEmpty()) {
            return new SearchOutcome(sortCars(cars, filters), active, List.of());
        }
        if (active.isEmpty()) {
            return new SearchOutcome(sortCars(searchCarsWithFilters(Map.of()), filters), List.of(), List.of());
        }

        int attempts = 1;
        for (int dropCount = 1; dropCount < active.size(); dropCount++) {
            for (List<String> combo : combinations(active, dropCount)) {
                if (attempts++ > MAX_SEARCH_ATTEMPTS) break;

                Map<String, Object> relaxed = withoutCriteria(filters, combo);
                List<CarSummaryResponse> found = searchCarsWithFilters(relaxed);
                if (!found.isEmpty()) {
                    List<String> kept = active.stream().filter(k -> !combo.contains(k)).toList();
                    return new SearchOutcome(sortCars(found, filters), kept, combo);
                }
            }
        }

        // Không tiêu chí nào cho ra kết quả — gợi ý xe đang sẵn sàng
        return new SearchOutcome(sortCars(searchCarsWithFilters(Map.of()), filters), List.of(), active);
    }

    private List<String> activeCriteria(Map<String, Object> filters) {
        return DROP_PRIORITY.stream()
                .filter(key -> "price".equals(key)
                        ? PRICE_GROUP.stream().anyMatch(filters::containsKey)
                        : filters.containsKey(key))
                .toList();
    }

    private Map<String, Object> withoutCriteria(Map<String, Object> filters, List<String> criteria) {
        Map<String, Object> copy = new LinkedHashMap<>(filters);
        for (String key : criteria) {
            if ("price".equals(key)) {
                PRICE_GROUP.forEach(copy::remove);
            } else {
                copy.remove(key);
            }
        }
        return copy;
    }

    /** Tổ hợp theo đúng thứ tự DROP_PRIORITY: tiêu chí dễ bỏ được thử bỏ trước. */
    private List<List<String>> combinations(List<String> source, int size) {
        List<List<String>> out = new ArrayList<>();
        buildCombinations(source, size, 0, new ArrayList<>(), out);
        return out;
    }

    private void buildCombinations(List<String> source, int size, int start,
                                   List<String> current, List<List<String>> out) {
        if (current.size() == size) {
            out.add(List.copyOf(current));
            return;
        }
        for (int i = start; i < source.size(); i++) {
            current.add(source.get(i));
            buildCombinations(source, size, i + 1, current, out);
            current.remove(current.size() - 1);
        }
    }

    /** Mô tả tiêu chí bằng tiếng Việt để hiển thị / giải thích cho khách. */
    private String describeCriterion(String key, Map<String, Object> filters) {
        return switch (key) {
            case "brand" -> "hãng " + filters.get("brand");
            case "name" -> "mẫu " + filters.get("name");
            case "seats" -> describeSeats(filters.get("seats"));
            case "location" -> "chi nhánh " + filters.get("location");
            case "transmission" -> "MANUAL".equals(Objects.toString(filters.get("transmission"), ""))
                    ? "số sàn" : "số tự động";
            case "fuelType" -> switch (Objects.toString(filters.get("fuelType"), "")) {
                case "ELECTRIC" -> "xe điện";
                case "HYBRID" -> "xe hybrid";
                case "DIESEL" -> "máy dầu";
                default -> "xe xăng";
            };
            case "price" -> describePrice(filters);
            default -> key;
        };
    }

    private String describeSeats(Object seats) {
        List<String> values = new ArrayList<>();
        if (seats instanceof List<?> list) {
            list.forEach(s -> values.add(s.toString()));
        } else if (seats != null) {
            values.add(seats.toString());
        }
        return values.isEmpty() ? "số chỗ" : String.join("/", values) + " chỗ";
    }

    private String describePrice(Map<String, Object> filters) {
        Object min = filters.get("minPrice");
        Object max = filters.get("maxPrice");
        if (min != null && max != null) {
            return String.format("giá %s–%s đ/ngày", compactPrice(min), compactPrice(max));
        }
        if (max != null) return "giá dưới " + compactPrice(max) + " đ/ngày";
        if (min != null) return "giá từ " + compactPrice(min) + " đ/ngày";
        return "khoảng giá";
    }

    private String compactPrice(Object value) {
        try {
            double v = new BigDecimal(value.toString()).doubleValue();
            if (v >= 1_000_000) {
                double tr = v / 1_000_000d;
                return (tr == Math.floor(tr) ? String.format("%.0f", tr) : String.format("%.1f", tr)) + "tr";
            }
            if (v >= 1_000) {
                double k = v / 1_000d;
                return (k == Math.floor(k) ? String.format("%.0f", k) : String.format("%.1f", k)) + "k";
            }
            return String.format("%,.0f", v);
        } catch (Exception e) {
            return Objects.toString(value, "");
        }
    }

    private List<String> describeCriteria(List<String> keys, Map<String, Object> filters) {
        return keys.stream().map(k -> describeCriterion(k, filters)).toList();
    }

    private List<CarSummaryResponse> sortCars(List<CarSummaryResponse> cars, Map<String, Object> filters) {
        String sort = Objects.toString(filters.get("sort"), "");
        Comparator<CarSummaryResponse> byPrice = Comparator.comparing(
                c -> c.pricePerDay() == null ? BigDecimal.ZERO : c.pricePerDay());
        Comparator<CarSummaryResponse> tieBreak =
                "priceDesc".equals(sort) ? byPrice.reversed() : byPrice;

        // Xe khớp nhiều tiêu chí gốc nhất luôn lên đầu, kể cả khi đã phải nới filter.
        return cars.stream()
                .sorted(Comparator.comparingInt((CarSummaryResponse c) -> -score(c, filters))
                        .thenComparing(tieBreak))
                .collect(Collectors.toList());
    }

    private int score(CarSummaryResponse c, Map<String, Object> filters) {
        int s = 0;
        String brand = normalize(Objects.toString(filters.get("brand"), ""));
        String name = normalize(Objects.toString(filters.get("name"), ""));
        String location = normalize(Objects.toString(filters.get("location"), ""));

        String carBrand = normalize(Objects.toString(c.brand(), ""));
        String carName = normalize(Objects.toString(c.name(), ""));
        String carPlace = normalize(Objects.toString(c.branchName(), "") + " " + Objects.toString(c.location(), ""));

        if (!name.isEmpty() && (carName.contains(name) || name.contains(carName))) s += 8;
        if (!brand.isEmpty() && carBrand.contains(brand)) s += 6;
        if (!location.isEmpty() && carPlace.contains(location)) s += 4;

        Object seats = filters.get("seats");
        if (seats instanceof List<?> list && c.seats() != null
                && list.stream().anyMatch(v -> v instanceof Number n && n.intValue() == c.seats())) {
            s += 5;
        }

        if (c.pricePerDay() != null) {
            Object max = filters.get("maxPrice");
            Object min = filters.get("minPrice");
            if (max != null && c.pricePerDay().compareTo(new BigDecimal(max.toString())) <= 0) s += 3;
            if (min != null && c.pricePerDay().compareTo(new BigDecimal(min.toString())) >= 0) s += 3;
        }
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

    private String buildFallbackAnswer(List<CarSummaryResponse> cars,
                                       List<String> matched,
                                       List<String> unmatched) {
        if (cars.isEmpty()) {
            return "Chưa thấy xe nào khớp yêu cầu.\n"
                    + "Thử: đổi khoảng giá, bỏ hãng cụ thể, hoặc chọn chi nhánh Hoàn Kiếm / Cầu Giấy / Thanh Xuân.";
        }

        StringBuilder sb = new StringBuilder();
        if (!unmatched.isEmpty()) {
            sb.append(String.format("Hiện không có xe nào thoả cả %s.\n",
                    joinLabels(concat(matched, unmatched))));
            if (matched.isEmpty()) {
                sb.append("Mình gợi ý vài xe đang sẵn sàng:\n\n");
            } else {
                sb.append(String.format("Mình giữ %s và bỏ %s, được các xe sau:\n\n",
                        joinLabels(matched), joinLabels(unmatched)));
            }
        } else if (matched.isEmpty()) {
            sb.append(String.format("Có %d xe đang sẵn sàng cho thuê:\n\n", cars.size()));
        } else {
            sb.append(String.format("Tìm thấy %d xe thoả %s:\n\n", cars.size(), joinLabels(matched)));
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

    private List<String> concat(List<String> a, List<String> b) {
        List<String> out = new ArrayList<>(a);
        out.addAll(b);
        return out;
    }

    private String joinLabels(List<String> labels) {
        if (labels.isEmpty()) return "";
        if (labels.size() == 1) return labels.get(0);
        return String.join(", ", labels.subList(0, labels.size() - 1))
                + " và " + labels.get(labels.size() - 1);
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
