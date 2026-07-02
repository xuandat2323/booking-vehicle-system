package vehicle.booking.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

@Component
public class MDCLoggingFilter extends OncePerRequestFilter {

    private static final Logger logger = LoggerFactory.getLogger(MDCLoggingFilter.class);

    private static final String REQUEST_ID_HEADER = "X-Request-ID";
    private static final String REQUEST_ID_MDC_KEY = "requestId";
    private static final String METHOD_MDC_KEY = "method";
    private static final String URI_MDC_KEY = "uri";
    private static final String CLIENT_IP_MDC_KEY = "clientIp";
    private static final String USER_PHONE_MDC_KEY = "userPhone";
    private static final String ROLE_MDC_KEY = "role";
    private static final String DURATION_MDC_KEY = "duration_ms";
    private static final String STATUS_MDC_KEY = "status";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        long startTime = System.currentTimeMillis();

        try {
            String requestId = request.getHeader(REQUEST_ID_HEADER);
            if (requestId == null || requestId.trim().isEmpty()) {
                requestId = UUID.randomUUID().toString();
            }

            String method = request.getMethod();
            String uri = request.getRequestURI();
            String clientIp = getClientIp(request);

            MDC.put(REQUEST_ID_MDC_KEY, requestId);
            MDC.put(METHOD_MDC_KEY, method);
            MDC.put(URI_MDC_KEY, uri);
            MDC.put(CLIENT_IP_MDC_KEY, clientIp);

            response.setHeader(REQUEST_ID_HEADER, requestId);

            filterChain.doFilter(request, response);

            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication != null && authentication.isAuthenticated() && !authentication.getPrincipal().equals("anonymousUser")) {
                MDC.put(USER_PHONE_MDC_KEY, authentication.getName());

                String roles = authentication.getAuthorities().stream()
                        .map(GrantedAuthority::getAuthority)
                        .collect(Collectors.joining(","));
                MDC.put(ROLE_MDC_KEY, roles);
            }

            long duration = System.currentTimeMillis() - startTime;
            int status = response.getStatus();

            MDC.put(DURATION_MDC_KEY, String.valueOf(duration));
            MDC.put(STATUS_MDC_KEY, String.valueOf(status));

            logger.info("[{} {}] {} {}ms", method, uri, status, duration);
            
        } finally {
            MDC.clear();
        }
    }

    private String getClientIp(HttpServletRequest request) {
        String xForwardedForHeader = request.getHeader("X-Forwarded-For");
        if (xForwardedForHeader != null && !xForwardedForHeader.trim().isEmpty()) {
            return xForwardedForHeader.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
