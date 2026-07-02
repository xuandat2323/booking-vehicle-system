package vehicle.booking.service;

import vehicle.booking.config.TwilioProperties;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import com.twilio.Twilio;
import com.twilio.exception.ApiException;
import com.twilio.rest.verify.v2.service.Verification;
import com.twilio.rest.verify.v2.service.VerificationCheck;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import com.google.firebase.auth.FirebaseAuthException;

@Service
@RequiredArgsConstructor
@Slf4j
public class PhoneVerificationService {
    private static final String SMS_CHANNEL = "sms";
    private static final String APPROVED_STATUS = "approved";
    private static final long OTP_EXPIRES_IN_SECONDS = 300;

    private final TwilioProperties twilioProperties;
    private final PhoneNumberService phoneNumberService;

    public long sendOtp(String normalizedPhone) {
        if (twilioProperties.isMockMode()) {
            log.info("Mock OTP sent to phone: {}", phoneNumberService.maskPhone(normalizedPhone));
            return OTP_EXPIRES_IN_SECONDS;
        }

        if (twilioProperties.isFirebaseMode()) {
            log.info("Firebase OTP mode: Client handles OTP sending for phone: {}", phoneNumberService.maskPhone(normalizedPhone));
            return OTP_EXPIRES_IN_SECONDS;
        }

        validateTwilioConfig();

        try {
            Twilio.init(twilioProperties.getAccountSid(), twilioProperties.getAuthToken());

            Verification.creator(
                    twilioProperties.getVerifyServiceSid(),
                    normalizedPhone,
                    SMS_CHANNEL
            ).create();

            log.info("Twilio OTP sent to phone: {}", phoneNumberService.maskPhone(normalizedPhone));
            return OTP_EXPIRES_IN_SECONDS;
        } catch (ApiException ex) {
            log.warn("Failed to send Twilio OTP to phone {}: {}",
                    phoneNumberService.maskPhone(normalizedPhone),
                    ex.getMessage()
            );
            throw new AppException(ErrorCode.PHONE_OTP_SEND_FAILED);
        }
    }

    public void verifyOtp(String normalizedPhone, String otp) {
        if (otp == null || otp.isBlank()) {
            throw new AppException(ErrorCode.PHONE_OTP_REQUIRED);
        }

        if (twilioProperties.isMockMode()) {
            verifyMockOtp(otp);
            log.info("Mock OTP verified for phone: {}", phoneNumberService.maskPhone(normalizedPhone));
            return;
        }

        if (twilioProperties.isFirebaseMode()) {
            verifyFirebaseOtp(normalizedPhone, otp);
            log.info("Firebase OTP verified for phone: {}", phoneNumberService.maskPhone(normalizedPhone));
            return;
        }

        validateTwilioConfig();
        verifyTwilioOtp(normalizedPhone, otp);
    }

    private void verifyMockOtp(String otp) {
        if (!twilioProperties.getMockOtp().equals(otp.trim())) {
            throw new AppException(ErrorCode.PHONE_OTP_INVALID);
        }
    }

    private void verifyTwilioOtp(String normalizedPhone, String otp) {
        try {
            Twilio.init(twilioProperties.getAccountSid(), twilioProperties.getAuthToken());

            VerificationCheck verificationCheck = VerificationCheck.creator(
                            twilioProperties.getVerifyServiceSid()
                    )
                    .setTo(normalizedPhone)
                    .setCode(otp.trim())
                    .create();

            if (!APPROVED_STATUS.equalsIgnoreCase(verificationCheck.getStatus())) {
                throw new AppException(ErrorCode.PHONE_OTP_INVALID);
            }

            log.info("Twilio OTP verified for phone: {}", phoneNumberService.maskPhone(normalizedPhone));
        } catch (AppException ex) {
            throw ex;
        } catch (ApiException ex) {
            log.warn("Failed to verify Twilio OTP for phone {}: {}",
                    phoneNumberService.maskPhone(normalizedPhone),
                    ex.getMessage()
            );
            throw new AppException(ErrorCode.PHONE_OTP_INVALID);
        }
    }

    private void validateTwilioConfig() {
        if (isBlank(twilioProperties.getAccountSid())
                || isBlank(twilioProperties.getAuthToken())
                || isBlank(twilioProperties.getVerifyServiceSid())) {
            throw new AppException(ErrorCode.TWILIO_CONFIG_INVALID);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private void verifyFirebaseOtp(String normalizedPhone, String idToken) {
        try {
            FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(idToken);
            String firebasePhone = (String) decodedToken.getClaims().get("phone_number");
            if (firebasePhone == null || firebasePhone.isBlank()) {
                log.warn("Phone number claim is missing in Firebase token");
                throw new AppException(ErrorCode.PHONE_OTP_INVALID);
            }
            
            String normalizedFirebasePhone = phoneNumberService.normalizeToE164(firebasePhone);
            String normalizedInputPhone = phoneNumberService.normalizeToE164(normalizedPhone);
            
            if (!normalizedFirebasePhone.equals(normalizedInputPhone)) {
                log.warn("Firebase token phone number '{}' does not match request phone number '{}'", 
                        phoneNumberService.maskPhone(normalizedFirebasePhone), 
                        phoneNumberService.maskPhone(normalizedInputPhone));
                throw new AppException(ErrorCode.PHONE_OTP_INVALID);
            }
        } catch (FirebaseAuthException e) {
            log.warn("Firebase token verification failed: {}", e.getMessage());
            throw new AppException(ErrorCode.PHONE_OTP_INVALID);
        } catch (AppException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Error during Firebase token verification: {}", e.getMessage());
            throw new AppException(ErrorCode.PHONE_OTP_INVALID);
        }
    }
}
