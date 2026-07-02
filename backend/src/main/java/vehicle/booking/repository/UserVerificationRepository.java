package vehicle.booking.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vehicle.booking.entity.UserVerification;
import java.util.Optional;

public interface UserVerificationRepository extends JpaRepository<UserVerification, Long> {
    Optional<UserVerification> findByUserUserId(Long userId);
    Optional<UserVerification> findByUserPhone(String phone);
}
