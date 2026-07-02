package vehicle.booking.controller;

import vehicle.booking.dto.request.SendPhoneOtpRequest;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.PhoneOtpSentResponse;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.service.PhoneNumberService;
import vehicle.booking.service.PhoneVerificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth/phone")
@RequiredArgsConstructor
public class PhoneVerificationController {

    private final PhoneNumberService phoneNumberService;
    private final PhoneVerificationService phoneVerificationService;
    private final UserRepository userRepository;

    @PostMapping("/send-otp")
    public ResponseEntity<ApiResponse<PhoneOtpSentResponse>> sendOtp(
            @RequestBody SendPhoneOtpRequest request) {

        String normalizedPhone = phoneNumberService.normalizeToE164(request.phone());

        if (userRepository.findByPhone(normalizedPhone).isPresent()) {
            throw new AppException(ErrorCode.AUTH_PHONE_ALREADY_EXISTS, normalizedPhone);
        }

        long expiresInSeconds = phoneVerificationService.sendOtp(normalizedPhone);
        PhoneOtpSentResponse response = new PhoneOtpSentResponse(normalizedPhone, expiresInSeconds);

        return ResponseEntity.ok(ApiResponse.ok("Ma OTP da duoc gui", response));
    }
}
