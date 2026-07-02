package vehicle.booking.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

@Getter
@Setter
@ConfigurationProperties(prefix = "twilio")
public class TwilioProperties {
    private TwilioMode mode = TwilioMode.MOCK;
    private String accountSid;
    private String authToken;
    private String verifyServiceSid;
    private String mockOtp = "123456";

    public boolean isMockMode() {
        return mode == TwilioMode.MOCK;
    }
    public boolean isTwilioMode() {
        return mode == TwilioMode.TWILIO;
    }
    public boolean isFirebaseMode() {
        return mode == TwilioMode.FIREBASE;
    }

}
