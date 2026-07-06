package vehicle.booking.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.service.ChatbotService;

import java.util.Map;

@RestController
@RequestMapping("/api/chatbot")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER')")
public class ChatbotController {

    private final ChatbotService chatbotService;

    /**
     * POST /api/chatbot/ask
     * Body: { "question": "Tôi muốn thuê xe 7 chỗ giá rẻ" }
     * Response: { answer, cars, filters, totalFound }
     */
    @PostMapping("/ask")
    public ResponseEntity<ApiResponse<Map<String, Object>>> ask(@RequestBody Map<String, String> body) {
        String question = body.getOrDefault("question", "").trim();
        if (question.isEmpty()) {
            return ResponseEntity.badRequest()
                    .body(new ApiResponse<>(false, "Vui lòng nhập câu hỏi", null));
        }

        Map<String, Object> result = chatbotService.processQuestion(question);
        return ResponseEntity.ok(new ApiResponse<>(true, "Trả lời thành công", result));
    }
}
