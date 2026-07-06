package vehicle.booking.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.security.core.parameters.P;
import org.springframework.stereotype.Repository;

import vehicle.booking.entity.Booking;
import vehicle.booking.entity.enums.BookingStatus;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface BookingRepository extends JpaRepository<Booking, Long> {

    @Query("""
    SELECT b FROM Booking b
    WHERE b.car.carId = :carId
      AND b.status IN ('PENDING', 'DEPOSIT_PAID', 'CONFIRMED', 'RENTING', 'RETURNED', 'COMPLETED')
      AND b.startDate <= :endDate
      AND b.endDate >= :startDate
    """)
    List<Booking> findOverlappingBookings(
            @Param("carId") Long carId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate
    );

    Page<Booking> findByUserUserId(Long userId, Pageable pageable);

    List<Booking> findByUserUserIdAndStatus(Long userId, BookingStatus status);

    List<Booking> findByStatus(BookingStatus status);

    @Query("""
    select b from Booking b
    join b.invoice i
    where b.status = 'PENDING'
      and i.status = 'UNPAID'
      and b.createdAt <= :cutoff
    """)
    List<Booking> findExpiredPendingUnpaidBookings(@Param("cutoff") LocalDateTime cutoff);

    @Query("""
    select b from Booking b
    where b.car.carId = :carId
        and b.status in :statuses
        and b.endDate >= :today
    """)
    List<Booking> findActiveBookingsByCarId(
            @Param("carId") Long carId,
            @Param("today") LocalDate today,
            @Param("statuses") List<BookingStatus> statuses);

    Page<Booking> findByCarOwnerUserId(Long ownerId, Pageable pageable);

    @Query("""
    SELECT COALESCE(SUM(b.totalPrice), 0)
    FROM Booking b
    WHERE b.car.owner.userId = :ownerId
      AND b.status = 'COMPLETED'
    """)
    java.math.BigDecimal sumCompletedEarningsByOwnerId(@Param("ownerId") Long ownerId);

    @Query("SELECT COUNT(DISTINCT b.car.carId) FROM Booking b WHERE b.car.owner.userId = :ownerId")
    long countDistinctCarsByOwnerId(@Param("ownerId") Long ownerId);
}

