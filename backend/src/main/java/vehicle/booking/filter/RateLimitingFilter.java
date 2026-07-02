package vehicle.booking.filter;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.ConsumptionProbe;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

@Component
public class RateLimitingFilter extends OncePerRequestFilter {
    private static final Logger logger = LoggerFactory.getLogger(RateLimitingFilter.class);

    private static final String LOGIN_PATH = "/api/auth/login";
    private static final String REGISTER_PATH = "/api/auth/register";
    private static final String PHONE_OTP_PATH = "/api/auth/phone/send-otp";

    private final Bandwidth loginBandwidth;
    private final Bandwidth registerBandwidth;
    private final Bandwidth phoneOtpBandwidth;
    private final Map<String, BucketHolder> buckets = new ConcurrentHashMap<>();

    @Value("${security.rate-limit.bucket-ttl:30m}")
    private Duration bucketTtl;

    public RateLimitingFilter(
            @Qualifier("loginBandwidth") Bandwidth loginBandwidth,
            @Qualifier("registerBandwidth") Bandwidth registerBandwidth,
            @Qualifier("phoneOtpBandwidth") Bandwidth phoneOtpBandwidth) {
        this.loginBandwidth = loginBandwidth;
        this.registerBandwidth = registerBandwidth;
        this.phoneOtpBandwidth = phoneOtpBandwidth;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        String path = request.getServletPath();
        String method = request.getMethod();
        String clientIp = resolveClientIp(request);

        Bucket bucket = null;
        if (HttpMethod.POST.matches(method) && LOGIN_PATH.equals(path)) {
            bucket = resolveBucket("login", clientIp, loginBandwidth);
        } else if (HttpMethod.POST.matches(method) && REGISTER_PATH.equals(path)) {
            bucket = resolveBucket("register", clientIp, registerBandwidth);
        } else if (HttpMethod.POST.matches(method) && PHONE_OTP_PATH.equals(path)) {
            bucket = resolveBucket("phone-otp", clientIp, phoneOtpBandwidth);
        }

        if (bucket == null) {
            filterChain.doFilter(request, response);
            return;
        }

        ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);
        if (probe.isConsumed()) {
            response.setHeader("X-RateLimit-Remaining", String.valueOf(probe.getRemainingTokens()));
            filterChain.doFilter(request, response);
            return;
        }

        long retryAfterSeconds = Math.max(1, TimeUnit.NANOSECONDS.toSeconds(probe.getNanosToWaitForRefill()));
        response.setCharacterEncoding("UTF-8");
        response.setContentType("application/json;charset=UTF-8");
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setHeader("Retry-After", String.valueOf(retryAfterSeconds));
        response.setHeader("X-RateLimit-Remaining", "0");
        response.getWriter().write("{\"success\":false,\"message\":\"Too many requests. Please try again later.\"}");
    }

    private Bucket resolveBucket(String endpoint, String clientIp, Bandwidth bandwidth) {
        String key = endpoint + ":" + clientIp;
        long now = System.currentTimeMillis();
        BucketHolder holder = buckets.computeIfAbsent(
                key,
                ignored -> new BucketHolder(Bucket.builder().addLimit(bandwidth).build(), now)
        );
        holder.touch(now);
        return holder.bucket();
    }

    @Scheduled(
            initialDelayString = "#{T(org.springframework.boot.convert.DurationStyle).detectAndParse('${security.rate-limit.bucket-cleanup-interval:5m}').toMillis()}",
            fixedDelayString = "#{T(org.springframework.boot.convert.DurationStyle).detectAndParse('${security.rate-limit.bucket-cleanup-interval:5m}').toMillis()}"
    )
    public void cleanupExpiredBuckets() {
        long ttlMillis = bucketTtl.toMillis();
        if (ttlMillis <= 0) {
            return;
        }

        long expireBefore = System.currentTimeMillis() - ttlMillis;
        int before = buckets.size();
        buckets.entrySet().removeIf(entry -> entry.getValue().lastAccessEpochMillis().get() < expireBefore);
        int removed = before - buckets.size();
        if (removed > 0) {
            logger.debug("Rate limit cleanup removed {} expired buckets, remaining {}", removed, buckets.size());
        }
    }

    private String resolveClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.trim().isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    private record BucketHolder(Bucket bucket, AtomicLong lastAccessEpochMillis) {
        private BucketHolder(Bucket bucket, long createdAt) {
            this(bucket, new AtomicLong(createdAt));
        }

        private void touch(long now) {
            lastAccessEpochMillis.set(now);
        }
    }
}
