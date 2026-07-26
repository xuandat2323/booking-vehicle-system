package vehicle.booking.service.impl;

import vehicle.booking.config.SepayConfig;
import vehicle.booking.dto.response.SepayPaymentResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.realtime.RealtimeEventHub;
import vehicle.booking.service.NotificationService;
import vehicle.booking.service.SepayService;
import vehicle.booking.entity.enums.NotificationType;
import vehicle.booking.util.UserDisplay;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class SepayServiceImpl implements SepayService {

    private static final Pattern CODE_PATTERN = Pattern.compile("GORENTO(\\d+)", Pattern.CASE_INSENSITIVE);

    private final BookingRepository bookingRepository;
    private final SepayConfig sepayConfig;
    private final RealtimeEventHub realtimeEventHub;
    private final NotificationService notificationService;

    @Override
    public SepayPaymentResponse createPayment(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.PENDING) {
            throw new AppException(ErrorCode.BOOKING_INVALID_STATUS_TRANSITION, booking.getStatus(), BookingStatus.DEPOSIT_PAID);
        }

        BigDecimal paymentAmount = booking.getDepositAmount() != null
                ? booking.getDepositAmount()
                : booking.getTotalPrice();
        long amount = paymentAmount.longValue();
        String code = paymentCode(bookingId);
        String qrImageUrl = buildQrImageUrl(amount, code);

        return new SepayPaymentResponse(
                bookingId,
                code,
                amount,
                sepayConfig.getBankBin(),
                sepayConfig.getBankName(),
                sepayConfig.getAccountNumber(),
                sepayConfig.getAccountName(),
                code,
                qrImageUrl,
                sepayConfig.isMockMode()
        );
    }

    @Override
    @Transactional
    public boolean handleWebhook(Map<String, Object> payload) {
        Object type = payload.get("transferType");
        if (type != null && !"in".equalsIgnoreCase(type.toString())) {
            return true; // ignore outgoing
        }

        long amount = toLong(payload.get("transferAmount"));
        String content = str(payload.get("content")) + " " + str(payload.get("code"));
        Long bookingId = extractBookingId(content);
        if (bookingId == null) {
            log.info("SePay webhook: no GORENTO code in content={}", content);
            return true;
        }

        Booking booking = bookingRepository.findById(bookingId).orElse(null);
        if (booking == null) {
            log.warn("SePay webhook: booking {} not found", bookingId);
            return true;
        }

        long expected = (booking.getDepositAmount() != null ? booking.getDepositAmount() : booking.getTotalPrice()).longValue();
        if (amount < expected) {
            log.warn("SePay webhook: amount {} < expected {} for booking {}", amount, expected, bookingId);
            return true;
        }

        markPaid(booking);
        return true;
    }

    @Override
    @Transactional
    public boolean simulatePaid(Long bookingId) {
        if (!sepayConfig.isMockMode()) {
            throw new AppException(ErrorCode.AUTH_FORBIDDEN);
        }
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));
        markPaid(booking);
        return true;
    }

    @Override
    public boolean isPaid(Long bookingId) {
        return bookingRepository.findById(bookingId)
                .map(b -> b.getStatus() != BookingStatus.PENDING)
                .orElse(false);
    }

    private void markPaid(Booking booking) {
        if (booking.getStatus() != BookingStatus.PENDING) {
            return;
        }
        booking.setStatus(BookingStatus.DEPOSIT_PAID);
        bookingRepository.saveAndFlush(booking);
        try {
            if (booking.getUser() != null) {
                realtimeEventHub.publishBookingUpdated(
                        booking.getUser().getUserId(),
                        booking.getBookingId(),
                        BookingStatus.DEPOSIT_PAID.name());
                notificationService.send(booking.getUser(),
                        "Đã đặt cọc thành công",
                        "Đơn #" + booking.getBookingId()
                                + " đã nhận cọc 30%. Vui lòng chờ admin xác nhận giữ xe.",
                        NotificationType.BOOKING_DEPOSIT_PAID, booking.getBookingId());
                notificationService.sendToAdmins(
                        "Có đơn chờ duyệt",
                        "Đơn #" + booking.getBookingId() + " của khách "
                                + UserDisplay.name(booking.getUser()) + " đã đặt cọc, cần xác nhận.",
                        NotificationType.BOOKING_DEPOSIT_PAID, booking.getBookingId());
            }
        } catch (Exception e) {
            log.warn("markPaid side-effects failed for booking {}: {}",
                    booking.getBookingId(), e.getMessage());
        }
        log.info("Booking {} marked DEPOSIT_PAID via SePay", booking.getBookingId());
    }

    private String paymentCode(Long bookingId) {
        return "GORENTO" + bookingId;
    }

    private String buildQrImageUrl(long amount, String addInfo) {
        // VietQR image API — hiển thị logo NH + số TK + số tiền + nội dung CK
        String encodedInfo = URLEncoder.encode(addInfo, StandardCharsets.UTF_8);
        String encodedName = URLEncoder.encode(sepayConfig.getAccountName(), StandardCharsets.UTF_8);
        return String.format(
                "https://img.vietqr.io/image/%s-%s-compact2.png?amount=%d&addInfo=%s&accountName=%s",
                sepayConfig.getBankBin(),
                sepayConfig.getAccountNumber(),
                amount,
                encodedInfo,
                encodedName
        );
    }

    private Long extractBookingId(String text) {
        if (text == null) return null;
        Matcher m = CODE_PATTERN.matcher(text.replace(" ", ""));
        if (m.find()) {
            try {
                return Long.parseLong(m.group(1));
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private static long toLong(Object v) {
        if (v == null) return 0;
        if (v instanceof Number n) return n.longValue();
        try {
            return Long.parseLong(v.toString());
        } catch (Exception e) {
            return 0;
        }
    }

    private static String str(Object v) {
        return v == null ? "" : v.toString();
    }
}
