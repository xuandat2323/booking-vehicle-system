package vehicle.booking.controller;

import vehicle.booking.dto.request.SendEmailOtpRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.EmailOtpSentResponse;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.service.EmailVerificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth/email")
@RequiredArgsConstructor
public class EmailVerificationController {

    private final EmailVerificationService emailVerificationService;

    @PostMapping("/send-otp")
    public ResponseEntity<ApiResponse<EmailOtpSentResponse>> sendOtp(
            @RequestBody SendEmailOtpRequest request) {

        if (request.email() == null || request.email().isBlank()) {
            throw new AppException(ErrorCode.EMAIL_REQUIRED);
        }

        String email = emailVerificationService.normalizeEmail(request.email());
        long expiresInSeconds = emailVerificationService.sendRegistrationOtp(email);
        EmailOtpSentResponse response = new EmailOtpSentResponse(email, expiresInSeconds);

        return ResponseEntity.ok(ApiResponse.ok("Mã OTP đã được gửi tới email", response));
    }
}
