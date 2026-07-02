package vehicle.booking.service.impl;

import vehicle.booking.dto.response.PaymentResponse;
import vehicle.booking.dto.response.PaymentSummaryResponse;
import vehicle.booking.entity.*;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.InvoiceStatus;
import vehicle.booking.entity.enums.PaymentMethod;
import vehicle.booking.entity.enums.PaymentStatus;
import vehicle.booking.exception.*;
import vehicle.booking.repository.*;
import vehicle.booking.service.EmailService;
import vehicle.booking.service.PaymentService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.expression.ExpressionException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PaymentServiceImpl implements PaymentService {
    private final PaymentRepository paymentRepository;
    private final InvoiceRepository invoiceRepository;
    private final UserRepository userRepository;
    private final BookingRepository bookingRepository;
    private final CarRepository carRepository;
    private final EmailService emailService;

    @Override
    public Page<PaymentSummaryResponse> getMyPayments(String currentUserPhone, Pageable pageable) {
        User currentUser = userRepository.findByPhone(currentUserPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        return paymentRepository.findByUserId(currentUser.getUserId(), pageable).map(this::mapToSummary);
    }

    @Override
    public PaymentResponse getPaymentById(Long paymentId, String currentUserPhone, boolean isAdmin) {
        Payment payment = paymentRepository.findById(paymentId).orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND, paymentId));
        if(!isAdmin){
            User currentUser = userRepository.findByPhone(currentUserPhone).orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
            Long ownerUserId = payment.getInvoice().getBooking().getUser().getUserId();
            if(!ownerUserId.equals(currentUser.getUserId())){
                throw new AppException(ErrorCode.PAYMENT_ACCESS_DENIED);
            }
        }
        return mapToResponse(payment);
    }

    @Override
    @Transactional
    public PaymentResponse confirmPayment(Long invoiceId, PaymentStatus result) {
        if(result != PaymentStatus.SUCCESS && result != PaymentStatus.FAILED){
            throw new AppException(ErrorCode.PAYMENT_INVALID_RESULT);
        }

        Invoice invoice = invoiceRepository.findById(invoiceId).orElseThrow(() -> new AppException(ErrorCode.INVOICE_NOT_FOUND));

        if(invoice.getStatus() != InvoiceStatus.UNPAID){
            throw new AppException(ErrorCode.INVOICE_INVALID_STATUS, invoice.getStatus());
        }

        if(paymentRepository.existsByInvoiceId(invoiceId)){
            throw new AppException(ErrorCode.INVOICE_ALREADY_EXISTS, invoiceId);
        }

        Booking booking = invoice.getBooking();
        Car car = booking.getCar();

        Payment payment = new Payment();
        payment.setInvoice(invoice);
        payment.setAmount(invoice.getTotalAmount());
        payment.setPaymentStatus(result);
        payment.setPaymentMethod(PaymentMethod.BANK_TRANSFER);
        paymentRepository.save(payment);

        if(result == PaymentStatus.SUCCESS){
            invoice.setStatus(InvoiceStatus.PAID);
            booking.setStatus(BookingStatus.COMPLETED);
            car.setStatus(CarStatus.BOOKED);
        } else {
            invoice.setStatus(InvoiceStatus.FAILED);
            booking.setStatus(BookingStatus.CANCELLED);
            car.setStatus(CarStatus.AVAILABLE);
        }

        invoiceRepository.save(invoice);
        bookingRepository.save(booking);
        carRepository.save(car);

        emailService.sendPaymentConfirmation(payment);

        return mapToResponse(payment);
    }

    @Override
    public Page<PaymentSummaryResponse> getAllPayments(PaymentStatus paymentStatus, Pageable pageable) {
        if (paymentStatus != null) {
            return paymentRepository.findByPaymentStatus(paymentStatus, pageable)
                    .map(this::mapToSummary);
        }
        return paymentRepository.findAll(pageable)
                .map(this::mapToSummary);
    }

    private PaymentResponse mapToResponse(Payment payment){
        return new PaymentResponse(
                payment.getPaymentId(),
                payment.getInvoice().getInvoiceId(),
                payment.getInvoice().getInvoiceNumber(),
                payment.getAmount(),
                payment.getPaymentMethod(),
                payment.getPaymentStatus(),
                payment.getTransactionCode(),
                payment.getCreateAt(),
                payment.getUpdateAt()
        );
    }

    private PaymentSummaryResponse mapToSummary(Payment payment){
        User user = payment.getInvoice().getBooking().getUser();
        return new PaymentSummaryResponse(
                payment.getPaymentId(),
                payment.getInvoice().getInvoiceId(),
                payment.getInvoice().getInvoiceNumber(),
                user.getUserId(),
                user.getName(),
                payment.getAmount(),
                payment.getPaymentMethod(),
                payment.getPaymentStatus(),
                payment.getCreateAt()
        );
    }
}
