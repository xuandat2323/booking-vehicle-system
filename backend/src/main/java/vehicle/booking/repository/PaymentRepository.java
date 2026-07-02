package vehicle.booking.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import vehicle.booking.entity.Payment;
import vehicle.booking.entity.enums.PaymentStatus;

import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    @Query("select count(p) > 0 from Payment p where p.invoice.invoiceId = :invoiceId")
    boolean existsByInvoiceId(@Param("invoiceId") Long invoiceId);

    @Query("select p from Payment p where p.invoice.invoiceId = :invoiceId")
    Optional<Payment> findByInvoiceId(@Param("invoiceId") Long invoiceId);

    @Query("select p from Payment p where p.invoice.booking.user.userId = :userId")
    Page<Payment> findByUserId(@Param("userId") Long userId, Pageable pageable);

    @Query("select p from Payment p where p.paymentStatus = :paymentStatus")
    Page<Payment> findByPaymentStatus(@Param("paymentStatus")PaymentStatus paymentStatus, Pageable pageable);
}

