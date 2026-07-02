package vehicle.booking.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import vehicle.booking.entity.Invoice;
import vehicle.booking.entity.enums.InvoiceStatus;

import java.util.List;
import java.util.Optional;

@Repository
public interface InvoiceRepository extends JpaRepository<Invoice, Long> {
    Optional<Invoice> findByBookingBookingId(Long bookingId);
    Page<Invoice> findByBookingUserUserId(Long userId, Pageable pageable);
    Page<Invoice> findByStatus(InvoiceStatus status, Pageable pageable);
    @Query(value = """
    SELECT MAX(i.invoice_number) FROM invoice i WHERE i.invoice_number LIKE CONCAT (:prefix, '%') """, nativeQuery = true)
    Optional<String> findMaxInvoiceNumberByPrefix(@Param("prefix") String prefix);
    boolean existsByBookingBookingId(Long bookingId);
}

