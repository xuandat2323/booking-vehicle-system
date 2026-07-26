package vehicle.booking.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import vehicle.booking.entity.EmailVerificationOtp;

import java.util.Optional;

public interface EmailVerificationOtpRepository extends JpaRepository<EmailVerificationOtp, Long> {

    Optional<EmailVerificationOtp> findFirstByEmailAndOtpAndUsedFalseOrderByCreatedAtDesc(String email, String otp);

    @Modifying(clearAutomatically = true)
    @Query("DELETE FROM EmailVerificationOtp t WHERE LOWER(t.email) = LOWER(:email)")
    void deleteByEmailIgnoreCase(@Param("email") String email);
}
