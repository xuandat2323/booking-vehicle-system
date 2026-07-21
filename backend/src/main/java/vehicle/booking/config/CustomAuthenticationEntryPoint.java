package vehicle.booking.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.exception.ErrorCode;

import java.io.IOException;

/**
 * Xử lý mọi request bị chặn ở tầng filter chain vì CHƯA xác thực
 * (thiếu Authorization header, token sai định dạng, token hết hạn...).
 *
 * Không có bean này, Spring Security 6 sẽ dùng Http403ForbiddenEntryPoint mặc định,
 * khiến các lỗi "chưa đăng nhập" trả về 403 thay vì 401 và không theo format ApiResponse chung.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CustomAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    @Override
    public void commence(HttpServletRequest request,
                          HttpServletResponse response,
                          AuthenticationException authException) throws IOException {
        log.warn("[AUTH_UNAUTHORIZED] {} {} - {}", request.getMethod(), request.getRequestURI(), authException.getMessage());

        ErrorCode errorCode = ErrorCode.AUTH_UNAUTHORIZED;
        response.setStatus(errorCode.getHttpStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        ApiResponse<Void> body = ApiResponse.error(errorCode.getCode(), errorCode.getMessage());
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
