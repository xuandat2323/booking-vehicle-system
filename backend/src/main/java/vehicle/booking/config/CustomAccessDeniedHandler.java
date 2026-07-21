package vehicle.booking.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.exception.ErrorCode;

import java.io.IOException;

/**
 * Xử lý request của user ĐÃ xác thực nhưng không đủ quyền (sai role, ví dụ
 * USER gọi vào /api/admin/**). Đây mới là trường hợp 403 hợp lệ.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CustomAccessDeniedHandler implements AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    @Override
    public void handle(HttpServletRequest request,
                        HttpServletResponse response,
                        AccessDeniedException accessDeniedException) throws IOException {
        log.warn("[AUTH_FORBIDDEN] {} {} - {}", request.getMethod(), request.getRequestURI(), accessDeniedException.getMessage());

        ErrorCode errorCode = ErrorCode.AUTH_FORBIDDEN;
        response.setStatus(errorCode.getHttpStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        ApiResponse<Void> body = ApiResponse.error(errorCode.getCode(), errorCode.getMessage());
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
