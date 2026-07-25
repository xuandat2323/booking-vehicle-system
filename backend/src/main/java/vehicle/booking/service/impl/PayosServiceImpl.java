package vehicle.booking.service.impl;

import vehicle.booking.config.PayosConfig;
import vehicle.booking.dto.response.PayosPaymentResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.service.PayosService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.Hibernate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import vn.payos.PayOS;
import vn.payos.model.v2.paymentRequests.CreatePaymentLinkRequest;
import vn.payos.model.v2.paymentRequests.CreatePaymentLinkResponse;
import vn.payos.model.v2.paymentRequests.PaymentLinkItem;
import vn.payos.model.webhooks.WebhookData;

import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
@Slf4j
public class PayosServiceImpl implements PayosService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final BookingRepository bookingRepository;
    private final PayosConfig payosConfig;
    private final PayOS payOS;

    @Override
    @Transactional(readOnly = true)
    public PayosPaymentResponse createPayment(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND, bookingId));

        if (booking.getStatus() != BookingStatus.PENDING) {
            throw new AppException(
                    ErrorCode.BOOKING_INVALID_STATUS_TRANSITION,
                    booking.getStatus(),
                    BookingStatus.DEPOSIT_PAID);
        }

        Hibernate.initialize(booking.getCar());
        Hibernate.initialize(booking.getUser());

        String carName = booking.getCar() != null && booking.getCar().getName() != null
                ? booking.getCar().getName().trim()
                : "Xe";
        String renterName = booking.getUser() != null && booking.getUser().getName() != null
                ? booking.getUser().getName().trim()
                : "Khach";
        String rentalPeriod = DATE_FMT.format(booking.getStartDate()) + " - " + DATE_FMT.format(booking.getEndDate());
        String paymentContent = carName + " - " + renterName + " - " + rentalPeriod;

        BigDecimal paymentAmount = booking.getDepositAmount() != null
                ? booking.getDepositAmount()
                : booking.getTotalPrice();
        long amount = paymentAmount.longValue();
        long orderCode = bookingId;
        // PayOS description tối đa ~25 ký tự
        String description = truncate(paymentContent, 25);

        String bankBin = payosConfig.getBankBin();
        String accountNumber = payosConfig.getAccountNumber();
        String accountName = payosConfig.getAccountName();
        String qrImageUrl = buildVietQrImageUrl(bankBin, accountNumber, accountName, amount, paymentContent);

        if (payosConfig.isMockMode()) {
            return new PayosPaymentResponse(
                    bookingId,
                    orderCode,
                    amount,
                    "",
                    "",
                    qrImageUrl,
                    "mock-" + bookingId,
                    bankBin,
                    accountNumber,
                    accountName,
                    description,
                    paymentContent,
                    carName,
                    renterName,
                    rentalPeriod,
                    true
            );
        }

        try {
            CreatePaymentLinkRequest request = CreatePaymentLinkRequest.builder()
                    .orderCode(orderCode)
                    .amount(amount)
                    .description(description)
                    .returnUrl(payosConfig.getReturnUrl())
                    .cancelUrl(payosConfig.getCancelUrl())
                    .item(PaymentLinkItem.builder()
                            .name(truncate(carName, 40))
                            .price(amount)
                            .quantity(1)
                            .build())
                    .build();

            CreatePaymentLinkResponse link = payOS.paymentRequests().create(request);
            String liveBin = StringUtils.hasText(link.getBin()) ? link.getBin() : bankBin;
            String liveAcc = StringUtils.hasText(link.getAccountNumber()) ? link.getAccountNumber() : accountNumber;
            String liveName = StringUtils.hasText(link.getAccountName()) ? link.getAccountName() : accountName;
            String liveDesc = link.getDescription() != null ? link.getDescription() : description;
            String liveQrImage = buildVietQrImageUrl(liveBin, liveAcc, liveName, amount, paymentContent);

            return new PayosPaymentResponse(
                    bookingId,
                    link.getOrderCode(),
                    link.getAmount() != null ? link.getAmount() : amount,
                    link.getCheckoutUrl(),
                    link.getQrCode(),
                    liveQrImage,
                    link.getPaymentLinkId(),
                    liveBin,
                    liveAcc,
                    liveName,
                    liveDesc,
                    paymentContent,
                    carName,
                    renterName,
                    rentalPeriod,
                    false
            );
        } catch (Exception e) {
            log.error("PayOS create payment failed for booking {}: {}", bookingId, e.getMessage());
            throw new AppException(ErrorCode.COMMON_INTERNAL_ERROR);
        }
    }

    @Override
    @Transactional
    public boolean handleWebhook(Object body) {
        if (payosConfig.isMockMode()) {
            log.info("PayOS webhook ignored in mock mode");
            return true;
        }
        try {
            WebhookData data = payOS.webhooks().verify(body);
            if (data == null || data.getOrderCode() == null) {
                return true;
            }
            if (!"00".equals(data.getCode())) {
                log.info("PayOS webhook non-success code={} order={}", data.getCode(), data.getOrderCode());
                return true;
            }

            Long bookingId = data.getOrderCode();
            Booking booking = bookingRepository.findById(bookingId).orElse(null);
            if (booking == null) {
                log.warn("PayOS webhook: booking {} not found", bookingId);
                return true;
            }

            long expected = (booking.getDepositAmount() != null
                    ? booking.getDepositAmount()
                    : booking.getTotalPrice()).longValue();
            if (data.getAmount() != null && data.getAmount() < expected) {
                log.warn("PayOS webhook: amount {} < expected {} for booking {}",
                        data.getAmount(), expected, bookingId);
                return true;
            }

            markPaid(booking);
            return true;
        } catch (Exception e) {
            log.error("PayOS webhook verify failed: {}", e.getMessage());
            throw new IllegalArgumentException("Invalid PayOS webhook: " + e.getMessage(), e);
        }
    }

    @Override
    @Transactional
    public boolean simulatePaid(Long bookingId) {
        if (!payosConfig.isMockMode()) {
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
        if (booking.getStatus() == BookingStatus.PENDING) {
            booking.setStatus(BookingStatus.DEPOSIT_PAID);
            bookingRepository.save(booking);
            log.info("Booking {} marked DEPOSIT_PAID via PayOS", booking.getBookingId());
        }
    }

    /**
     * Ảnh VietQR gắn STK + số tiền + nội dung CK (gen bởi img.vietqr.io).
     */
    private String buildVietQrImageUrl(
            String bin, String account, String accountName, long amount, String addInfo) {
        if (!StringUtils.hasText(bin) || !StringUtils.hasText(account)) {
            return "";
        }
        String info = URLEncoder.encode(truncate(addInfo, 100), StandardCharsets.UTF_8);
        String name = URLEncoder.encode(accountName != null ? accountName : "GORENTO", StandardCharsets.UTF_8);
        return String.format(
                "https://img.vietqr.io/image/%s-%s-compact2.png?amount=%d&addInfo=%s&accountName=%s",
                bin.trim(),
                account.trim(),
                amount,
                info,
                name
        );
    }

    private static String truncate(String s, int max) {
        if (s == null) return "";
        String t = s.trim();
        return t.length() <= max ? t : t.substring(0, max);
    }
}
