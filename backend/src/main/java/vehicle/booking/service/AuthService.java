package vehicle.booking.service;

import vehicle.booking.dto.request.LoginRequest;
import vehicle.booking.dto.request.RefreshTokenRequest;
import vehicle.booking.dto.request.RegisterRequest;
import vehicle.booking.dto.response.AuthenticationResponse;
import vehicle.booking.entity.RefreshToken;
import vehicle.booking.entity.User;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private UserDetailsService userDetailsService;

    @Autowired
    private AuthenticationManager authenticationManager;

    @Autowired
    private RefreshTokenService refreshTokenService;

    @Autowired
    private PhoneNumberService phoneNumberService;

    @Autowired
    private EmailVerificationService emailVerificationService;

    public AuthenticationResponse register(RegisterRequest request) {
        String normalizedPhone = phoneNumberService.normalizeToE164(request.phone());
        String normalizedEmail = emailVerificationService.normalizeEmail(request.email());

        if (userRepository.findByPhone(normalizedPhone).isPresent()) {
            throw new AppException(ErrorCode.AUTH_PHONE_ALREADY_EXISTS, normalizedPhone);
        }
        if (userRepository.findByEmail(normalizedEmail).isPresent()) {
            throw new AppException(ErrorCode.AUTH_EMAIL_ALREADY_EXISTS, normalizedEmail);
        }

        emailVerificationService.verifyRegistrationOtp(normalizedEmail, request.otp());

        User user = new User();
        String displayName = request.name();
        if (displayName == null || displayName.isBlank()) {
            // App đăng ký cũ chỉ gửi SĐT — tránh name null trong thông báo/admin.
            String tail = normalizedPhone.length() >= 4
                    ? normalizedPhone.substring(normalizedPhone.length() - 4)
                    : normalizedPhone;
            displayName = "Khách " + tail;
        }
        user.setName(displayName.trim());
        user.setEmail(normalizedEmail);
        user.setPhone(normalizedPhone);
        user.setDriveLicense(request.driveLicense());
        user.setPassword(passwordEncoder.encode(request.password()));
        user.setRole(request.role() != null && !request.role().isEmpty() ? request.role() : "user");

        userRepository.save(user);
        log.info("User registered successfully: {}", user.getPhone());

        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getPhone());
        String accessToken = jwtService.generateToken(userDetails);
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);

        return new AuthenticationResponse(
                accessToken,
                refreshToken.getToken(),
                user.getUserId(),
                user.getName(),
                user.getPhone(),
                user.getRole()
        );
    }

    public AuthenticationResponse login(LoginRequest request) {
        String normalizedPhone = phoneNumberService.normalizeToE164(request.phone());

        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(normalizedPhone, request.password())
            );
        } catch (BadCredentialsException e) {
            log.warn("Invalid credentials for phone: {}", normalizedPhone);
            throw new AppException(ErrorCode.AUTH_INVALID_CREDENTIALS);
        }

        User user = userRepository.findByPhone(normalizedPhone).orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        UserDetails userDetails = userDetailsService.loadUserByUsername(normalizedPhone);
        String accessToken = jwtService.generateToken(userDetails);
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);

        log.info("User logged in: {}", user.getPhone());

        return new AuthenticationResponse(
                accessToken,
                refreshToken.getToken(),
                user.getUserId(),
                user.getName(),
                user.getPhone(),
                user.getRole()
        );
    }

    @Transactional
    public AuthenticationResponse refresh(RefreshTokenRequest request){
        if (request == null || request.refreshToken() == null || request.refreshToken().isBlank()) {
            throw new AppException(ErrorCode.AUTH_REFRESH_TOKEN_INVALID);
        }

        RefreshToken newRefreshToken = refreshTokenService.rotateRefreshToken(request.refreshToken());

        // Phải đọc user trong cùng transaction — tránh LazyInitializationException → HTTP 500.
        User user = newRefreshToken.getUser();
        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getPhone());
        String newAccessToken = jwtService.generateToken(userDetails);

        log.info("Token refreshed for user: {}", user.getPhone());

        return new AuthenticationResponse(
                newAccessToken,
                newRefreshToken.getToken(),
                user.getUserId(),
                user.getName(),
                user.getPhone(),
                user.getRole()
        );
    }

    public void logout(String currentUserPhone){
        String normalizedPhone = phoneNumberService.normalizeToE164(currentUserPhone);
        User user = userRepository.findByPhone(normalizedPhone).orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        refreshTokenService.deleteByUserId(user.getUserId());
        log.info("User logged out: {}", normalizedPhone);
    }
}
