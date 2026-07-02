package vehicle.booking.config;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Refill;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;

@Configuration
public class RateLimitConfig {

    @Value("${security.rate-limit.login.capacity:10}")
    private long loginCapacity;

    @Value("${security.rate-limit.login.refill-tokens:10}")
    private long loginRefillTokens;

    @Value("${security.rate-limit.login.refill-duration:1m}")
    private Duration loginRefillDuration;

    @Value("${security.rate-limit.register.capacity:5}")
    private long registerCapacity;

    @Value("${security.rate-limit.register.refill-tokens:5}")
    private long registerRefillTokens;

    @Value("${security.rate-limit.register.refill-duration:1m}")
    private Duration registerRefillDuration;

    @Value("${security.rate-limit.phone-otp.capacity:3}")
    private long phoneOtpCapacity;

    @Value("${security.rate-limit.phone-otp.refill-tokens:3}")
    private long phoneOtpRefillTokens;

    @Value("${security.rate-limit.phone-otp.refill-duration:1m}")
    private Duration phoneOtpRefillDuration;

    @Bean
    public Bandwidth loginBandwidth() {
        return Bandwidth.classic(
                loginCapacity,
                Refill.intervally(loginRefillTokens, loginRefillDuration)
        );
    }

    @Bean
    public Bandwidth registerBandwidth() {
        return Bandwidth.classic(
                registerCapacity,
                Refill.intervally(registerRefillTokens, registerRefillDuration)
        );
    }

    @Bean
    public Bandwidth phoneOtpBandwidth() {
        return Bandwidth.classic(
                phoneOtpCapacity,
                Refill.intervally(phoneOtpRefillTokens, phoneOtpRefillDuration)
        );
    }
}
