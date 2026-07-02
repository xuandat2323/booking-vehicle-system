package vehicle.booking.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import vehicle.booking.entity.User;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByPhone(String phone);
    Optional<User> findByEmail(String email);

    @Query("""
    SELECT u FROM User u
    WHERE (:search IS NULL OR :search = ''
        OR LOWER(u.name) LIKE LOWER(CONCAT('%', :search, '%'))
        OR LOWER(u.email) LIKE LOWER(CONCAT('%', :search, '%'))
        OR u.phone LIKE CONCAT('%', :search, '%'))
    ORDER BY u.userId DESC
    """)
    Page<User> searchUsers(@Param("search") String search, Pageable pageable);

    long countByRole(String role);
}
