package vehicle.booking.config;

import lombok.Getter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;
import vn.payos.PayOS;
import vn.payos.core.ClientOptions;

@Configuration
@Getter
public class PayosConfig {

    @Value("${payos.mode:mock}")
    private String mode;

    @Value("${payos.client-id:}")
    private String clientId;

    @Value("${payos.api-key:}")
    private String apiKey;

    @Value("${payos.checksum-key:}")
    private String checksumKey;

    @Value("${payos.return-url:http://localhost:8080/api/payments/payos/return}")
    private String returnUrl;

    @Value("${payos.cancel-url:http://localhost:8080/api/payments/payos/cancel}")
    private String cancelUrl;

    @Value("${payos.frontend-url:http://localhost:49457/#/bookings}")
    private String frontendUrl;

    /** BIN + STK dùng gen ảnh VietQR (mock hoặc fallback). */
    @Value("${payos.bank-bin:970422}")
    private String bankBin;

    @Value("${payos.account-number:}")
    private String accountNumber;

    @Value("${payos.account-name:GORENTO}")
    private String accountName;

    public boolean isMockMode() {
        return !"live".equalsIgnoreCase(mode) || !hasCredentials();
    }

    public boolean hasCredentials() {
        return StringUtils.hasText(clientId)
                && StringUtils.hasText(apiKey)
                && StringUtils.hasText(checksumKey)
                && !"YOUR_PAYOS_CLIENT_ID".equals(clientId);
    }

    @Bean
    public PayOS payOS() {
        if (!hasCredentials()) {
            return new PayOS("UNUSED", "UNUSED", "UNUSED");
        }
        ClientOptions options = ClientOptions.builder()
                .clientId(clientId)
                .apiKey(apiKey)
                .checksumKey(checksumKey)
                .logLevel(ClientOptions.LogLevel.INFO)
                .build();
        return new PayOS(options);
    }
}
