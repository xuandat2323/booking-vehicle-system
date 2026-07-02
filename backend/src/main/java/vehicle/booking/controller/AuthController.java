package vehicle.booking.controller;

import vehicle.booking.dto.request.*;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.AuthenticationResponse;
import vehicle.booking.service.AuthService;
import vehicle.booking.service.PasswordResetService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired
    private AuthService authService;

    @Autowired
    private PasswordResetService passwordResetService;

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthenticationResponse>> register(@RequestBody RegisterRequest request) {
        if (request.phone() == null || request.phone().isEmpty() ||
                request.password() == null || request.password().isEmpty() ||
                request.otp() == null || request.otp().isBlank()) {
            return ResponseEntity.badRequest().body(
                    new ApiResponse<>(false, "Vui lòng điền đầy đủ thông tin", null));
        }

        AuthenticationResponse response = authService.register(request);
        return ResponseEntity.ok(new ApiResponse<>(true, "Đăng ký thành công", response));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthenticationResponse>> login(@RequestBody LoginRequest request) {
        if (request.phone() == null || request.password() == null) {
            return ResponseEntity.badRequest().body(
                    new ApiResponse<>(false, "Thiếu thông tin đăng nhập", null));
        }

        AuthenticationResponse response = authService.login(request);
        return ResponseEntity.ok(new ApiResponse<>(true, "Đăng nhập thành công", response));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthenticationResponse>> refresh(@RequestBody RefreshTokenRequest request) {
        AuthenticationResponse response = authService.refresh(request);
        return ResponseEntity.ok(new ApiResponse<>(true, "Làm mới token thành công", response));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<String>> logout(Authentication authentication){
        authService.logout(authentication.getName());
        return ResponseEntity.ok(new ApiResponse<>(true, "Đăng xuất thành công", null));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<ApiResponse<String>> forgotPassword(@RequestBody ForgotPasswordRequest request) {
        if (request.email() == null || request.email().isBlank()) {
            return ResponseEntity.badRequest()
                    .body(new ApiResponse<>(false, "Vui lòng nhập email", null));
        }
        passwordResetService.sendOtp(request);
        return ResponseEntity.ok(new ApiResponse<>(true,
                "Nếu email tồn tại trong hệ thống, bạn sẽ nhận được mã OTP trong vài giây", null));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<ApiResponse<String>> resetPassword(@RequestBody ResetPasswordRequest request) {
        passwordResetService.resetPassword(request);
        return ResponseEntity.ok(new ApiResponse<>(true, "Đặt lại mật khẩu thành công", null));
    }





}
