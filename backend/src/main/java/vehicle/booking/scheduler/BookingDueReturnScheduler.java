package vehicle.booking.scheduler;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import vehicle.booking.service.BookingService;

import java.time.LocalDate;
import java.util.List;

/**
 * Mỗi giờ quét đơn RENTING có end_date = hôm nay và gửi thông báo đến hạn trả xe (1 lần/đơn).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BookingDueReturnScheduler {

    private final BookingService bookingService;

    @Scheduled(cron = "${booking.due-return.cron:0 0 * * * *}")
    public void notifyDueReturnBookings() {
        LocalDate today = LocalDate.now();
        List<Long> notifiedIds = bookingService.notifyDueReturnBookings(today);
        if (notifiedIds.isEmpty()) {
            log.debug("Due-return reminder: no booking notified (today={})", today);
            return;
        }
        log.info("Due-return reminder: notified {} bookings (today={}), bookingIds={}",
                notifiedIds.size(), today, notifiedIds);
    }
}
