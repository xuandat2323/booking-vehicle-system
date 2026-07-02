package vehicle.booking.scheduler;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.convert.DurationStyle;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import vehicle.booking.service.BookingService;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class BookingExpirationScheduler {

    private final BookingService bookingService;

    @Value("${booking.expiration.pending-payment-timeout:15m}")
    private String pendingPaymentTimeoutText;

    private Duration pendingPaymentTimeout;

    @PostConstruct
    void init() {
        this.pendingPaymentTimeout = DurationStyle.detectAndParse(pendingPaymentTimeoutText);
    }

    @Scheduled(fixedDelayString = "#{T(org.springframework.boot.convert.DurationStyle).detectAndParse('${booking.expiration.cleanup-interval:5m}').toMillis()}")
    public void expirePendingUnpaidBookings() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime cutoff = now.minus(pendingPaymentTimeout);
        List<Long> expiredBookingIds = bookingService.expirePendingUnpaidBookings(cutoff);

        if (expiredBookingIds.isEmpty()) {
            log.debug("Booking expiration run completed: no expired booking found (cutoff={})", cutoff);
            return;
        }

        log.info(
                "Booking expiration run completed: expired {} bookings (cutoff={}), bookingIds={}",
                expiredBookingIds.size(),
                cutoff,
                expiredBookingIds
        );
    }
}
