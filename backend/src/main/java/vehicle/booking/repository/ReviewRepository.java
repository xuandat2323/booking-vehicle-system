package vehicle.booking.repository;

import vehicle.booking.entity.Review;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ReviewRepository extends JpaRepository<Review, Long> {
    
    Page<Review> findByCarCarIdOrderByCreatedAtDesc(Long carId, Pageable pageable);
    
    boolean existsByBookingBookingId(Long bookingId);
    
    Review findByBookingBookingId(Long bookingId);
    
    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.car.carId = :carId")
    Double getAverageRatingByCarId(@Param("carId") Long carId);
    
    @Query("SELECT COUNT(r) FROM Review r WHERE r.car.carId = :carId")
    Long countByCarId(@Param("carId") Long carId);
}
