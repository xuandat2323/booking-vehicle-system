package vehicle.booking.service;

import vehicle.booking.entity.RefreshToken;
import vehicle.booking.entity.User;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RefreshTokenService {
    private final RefreshTokenRepository refreshTokenRepository;
    @Value("${jwt.refresh-expiration}")
    private long refreshExpiration;

    @Transactional
    public RefreshToken createRefreshToken(User user) {
        refreshTokenRepository.deleteByUserId(user.getUserId());

        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setUser(user);
        refreshToken.setToken(UUID.randomUUID().toString());
        refreshToken.setExpiresAt(LocalDateTime.now().plusSeconds(refreshExpiration / 1000));
        return refreshTokenRepository.save(refreshToken);
    }

    @Transactional
    public RefreshToken rotateRefreshToken(String token){
        RefreshToken refreshToken = refreshTokenRepository.findByToken(token).orElseThrow(() -> new AppException(ErrorCode.AUTH_REFRESH_TOKEN_INVALID));
        if(refreshToken.isExpired()){
            refreshTokenRepository.delete(refreshToken);
            throw new AppException(ErrorCode.AUTH_REFRESH_TOKEN_EXPIRED);
        }
        User user = refreshToken.getUser();
        refreshTokenRepository.delete(refreshToken);
        return createRefreshToken(user);
    }

    @Transactional
    public void deleteByUserId(Long userId){
        refreshTokenRepository.deleteByUserId(userId);
    }
}
