package vehicle.booking.service;

import vehicle.booking.dto.request.ForgotPasswordRequest;
import vehicle.booking.dto.request.ResetPasswordRequest;
import vehicle.booking.entity.PasswordResetToken;
import vehicle.booking.entity.User;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.PasswordResetTokenRepository;
import vehicle.booking.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class PasswordResetService {

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private static final int OTP_EXPIRATION_MINUTES = 1;

    @Transactional
    public void sendOtp(ForgotPasswordRequest request) {
        Optional<User> userOpt = userRepository.findByEmail(request.email());

        if (userOpt.isEmpty()) {
            log.warn("Forgot password requested for non-existent email: {}", request.email());
            return;
        }

        User user = userOpt.get();

        tokenRepository.deleteByUserId(user.getUserId());

        String otp = String.valueOf(100000 + SECURE_RANDOM.nextInt(900000));

        PasswordResetToken token = new PasswordResetToken();
        token.setUser(user);
        token.setOtp(otp);
        token.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_EXPIRATION_MINUTES));
        token.setUsed(false);
        tokenRepository.save(token);

        emailService.sendOtpResetPassword(user, otp);

        log.info("OTP generated and email dispatched for user: {}", user.getEmail());
    }

    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        if (!request.newPassword().equals(request.confirmPassword())) {
            throw new AppException(ErrorCode.PASSWORD_MISMATCH);
        }

        PasswordResetToken token = tokenRepository
                .findByOtpAndUserEmail(request.otp(), request.email())
                .orElseThrow(() -> new AppException(ErrorCode.PASSWORD_RESET_OTP_INVALID));

        if (token.isUsed()) {
            throw new AppException(ErrorCode.PASSWORD_RESET_OTP_USED);
        }

        if (token.isExpired()) {
            throw new AppException(ErrorCode.PASSWORD_RESET_OTP_EXPIRED);
        }

        User user = token.getUser();
        user.setPassword(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);

        token.setUsed(true);
        tokenRepository.save(token);

        log.info("Password reset successfully for user: {}", user.getEmail());
    }
}