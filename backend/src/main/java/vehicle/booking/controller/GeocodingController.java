package vehicle.booking.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.Collections;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/geo")
@RequiredArgsConstructor
@Slf4j
public class GeocodingController {

    @Value("${goong.api-key}")
    private String apiKey;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    private static final String GOONG_BASE = "https://rsapi.goong.io";
    // Default focus: Hà Nội — biases ranking toward Vietnam
    private static final String DEFAULT_FOCUS = "21.0285,105.8542";

    @SuppressWarnings("unchecked")
    private Object fetch(String url) throws Exception {
        var resp = restTemplate.getForEntity(url, String.class);
        return objectMapper.readValue(resp.getBody(), Object.class);
    }

    /**
     * Autocomplete search → [{place_name, id (place_id), lat: 0, lon: 0}]
     * lat/lon are 0 — client must call /api/geo/place to resolve coordinates on selection.
     */
    @GetMapping("/search")
    public ResponseEntity<Object> search(
            @RequestParam String text,
            @RequestParam(defaultValue = DEFAULT_FOCUS) String focus,
            @RequestParam(defaultValue = "10") int limit) {
        String url = UriComponentsBuilder
                .fromHttpUrl(GOONG_BASE + "/Place/AutoComplete")
                .queryParam("api_key", apiKey)
                .queryParam("input", text.trim())
                .queryParam("location", focus)
                .queryParam("more_compound", "true")
                .toUriString();
        try {
            Map<String, Object> body = (Map<String, Object>) fetch(url);
            List<Map<String, Object>> predictions =
                    (List<Map<String, Object>>) body.getOrDefault("predictions", Collections.emptyList());

            List<Map<String, Object>> results = predictions.stream()
                    .limit(limit)
                    .map(p -> Map.<String, Object>of(
                            "place_name", p.getOrDefault("description", ""),
                            "id", p.getOrDefault("place_id", ""),
                            "lat", 0.0,
                            "lon", 0.0
                    ))
                    .toList();

            return ResponseEntity.ok(results);
        } catch (Exception e) {
            log.warn("Goong autocomplete failed: {}", e.getMessage());
            return ResponseEntity.ok(Collections.emptyList());
        }
    }

    /**
     * Resolve place_id → lat/lng + address.
     * Called once when user selects a suggestion.
     */
    @GetMapping("/place")
    public ResponseEntity<Object> place(@RequestParam String placeId) {
        String url = UriComponentsBuilder
                .fromHttpUrl(GOONG_BASE + "/Place/Detail")
                .queryParam("place_id", placeId)
                .queryParam("api_key", apiKey)
                .toUriString();
        try {
            Map<String, Object> body = (Map<String, Object>) fetch(url);
            Map<String, Object> result = (Map<String, Object>) body.get("result");
            if (result == null) return ResponseEntity.ok(Collections.emptyMap());

            Map<String, Object> geometry = (Map<String, Object>) result.get("geometry");
            Map<String, Object> location = geometry != null ? (Map<String, Object>) geometry.get("location") : null;
            double lat = location != null ? ((Number) location.getOrDefault("lat", 0.0)).doubleValue() : 0.0;
            double lng = location != null ? ((Number) location.getOrDefault("lng", 0.0)).doubleValue() : 0.0;

            return ResponseEntity.ok(Map.of(
                    "place_name", result.getOrDefault("formatted_address", ""),
                    "lat", lat,
                    "lon", lng
            ));
        } catch (Exception e) {
            log.warn("Goong place detail failed: {}", e.getMessage());
            return ResponseEntity.ok(Collections.emptyMap());
        }
    }

    /**
     * Reverse geocode lat/lng → {display_name}
     */
    @GetMapping("/reverse")
    public ResponseEntity<Object> reverse(
            @RequestParam double lat,
            @RequestParam double lng) {
        String url = UriComponentsBuilder
                .fromHttpUrl(GOONG_BASE + "/Geocode")
                .queryParam("latlng", lat + "," + lng)
                .queryParam("api_key", apiKey)
                .toUriString();
        try {
            Map<String, Object> body = (Map<String, Object>) fetch(url);
            List<Map<String, Object>> results =
                    (List<Map<String, Object>>) body.getOrDefault("results", Collections.emptyList());
            String displayName = results.isEmpty() ? lat + ", " + lng
                    : (String) results.get(0).getOrDefault("formatted_address", lat + ", " + lng);
            return ResponseEntity.ok(Map.of("display_name", displayName));
        } catch (Exception e) {
            log.warn("Goong reverse geocode failed: {}", e.getMessage());
            return ResponseEntity.ok(Collections.emptyMap());
        }
    }
}
