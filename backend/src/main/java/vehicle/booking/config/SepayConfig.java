package vehicle.booking.config;

import lombok.Getter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

@Configuration
@Getter
public class SepayConfig {

    /** mock = demo confirm không cần chuyển khoản thật; live = chỉ webhook SePay */
    @Value("${sepay.mode:mock}")
    private String mode;

    /** BIN ngân hàng (MB=970422, VCB=970436, TCB=970407…) */
    @Value("${sepay.bank-bin:970422}")
    private String bankBin;

    @Value("${sepay.bank-name:MBBank}")
    private String bankName;

    @Value("${sepay.account-number:0123456789}")
    private String accountNumber;

    @Value("${sepay.account-name:CONG TY GORENTO}")
    private String accountName;

    /** Optional API key header for webhook (Authorization: Apikey xxx) */
    @Value("${sepay.webhook-api-key:}")
    private String webhookApiKey;

    public boolean isMockMode() {
        return !"live".equalsIgnoreCase(mode);
    }
}
