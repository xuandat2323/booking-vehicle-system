package vehicle.booking.service;

import vehicle.booking.entity.EmailVerificationOtp;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.EmailVerificationOtpRepository;
import vehicle.booking.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailVerificationService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final int OTP_EXPIRATION_MINUTES = 5;
    private static final long OTP_EXPIRES_IN_SECONDS = OTP_EXPIRATION_MINUTES * 60L;
    private static final Pattern EMAIL_PATTERN =
            Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");

    private final EmailVerificationOtpRepository otpRepository;
    private final UserRepository userRepository;
    private final EmailService emailService;

    @Transactional
    public long sendRegistrationOtp(String rawEmail) {
        String email = normalizeEmail(rawEmail);

        if (userRepository.findByEmail(email).isPresent()) {
            throw new AppException(ErrorCode.AUTH_EMAIL_ALREADY_EXISTS, email);
        }

        otpRepository.deleteByEmailIgnoreCase(email);

        String otp = String.valueOf(100000 + SECURE_RANDOM.nextInt(900000));

        EmailVerificationOtp token = new EmailVerificationOtp();
        token.setEmail(email);
        token.setOtp(otp);
        token.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_EXPIRATION_MINUTES));
        token.setUsed(false);
        otpRepository.save(token);

        // Dev: in OTP ra console để test khi SMTP lỗi / chậm.
        log.info("Registration OTP for {} = {}", maskEmail(email), otp);

        emailService.sendRegistrationOtp(email, otp);

        log.info("Registration OTP sent to email: {}", maskEmail(email));
        return OTP_EXPIRES_IN_SECONDS;
    }

    @Transactional
    public void verifyRegistrationOtp(String rawEmail, String otp) {
        if (otp == null || otp.isBlank()) {
            throw new AppException(ErrorCode.EMAIL_OTP_REQUIRED);
        }

        String email = normalizeEmail(rawEmail);

        EmailVerificationOtp token = otpRepository
                .findFirstByEmailAndOtpAndUsedFalseOrderByCreatedAtDesc(email, otp.trim())
                .orElseThrow(() -> new AppException(ErrorCode.EMAIL_OTP_INVALID));

        if (token.isExpired()) {
            throw new AppException(ErrorCode.EMAIL_OTP_EXPIRED);
        }

        token.setUsed(true);
        otpRepository.save(token);
        log.info("Registration OTP verified for email: {}", maskEmail(email));
    }

    public String normalizeEmail(String rawEmail) {
        if (rawEmail == null || rawEmail.isBlank()) {
            throw new AppException(ErrorCode.EMAIL_REQUIRED);
        }
        String email = rawEmail.trim().toLowerCase(Locale.ROOT);
        if (!EMAIL_PATTERN.matcher(email).matches()) {
            throw new AppException(ErrorCode.EMAIL_INVALID);
        }
        return email;
    }

    private String maskEmail(String email) {
        int at = email.indexOf('@');
        if (at <= 1) return "***";
        return email.charAt(0) + "***" + email.substring(at);
    }
}
