package vehicle.booking.service.impl;

import vehicle.booking.dto.response.InvoiceResponse;
import vehicle.booking.dto.response.InvoiceSummaryResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.Invoice;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.entity.enums.InvoiceStatus;
import vehicle.booking.exception.*;
import vehicle.booking.repository.InvoiceRepository;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.service.InvoiceService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class InvoiceServiceImpl implements InvoiceService {
    private final InvoiceRepository invoiceRepository;
    private final UserRepository userRepository;

    @Override
    @Transactional
    public InvoiceResponse createInvoiceForBooking(Booking booking){
        if(invoiceRepository.existsByBookingBookingId(booking.getBookingId())) {
            throw new AppException(ErrorCode.INVOICE_ALREADY_EXISTS, booking.getBookingId());
        }

        String invoiceNumber = generateInvoiceNumber();

        Invoice invoice = new Invoice();
        invoice.setBooking(booking);
        invoice.setInvoiceNumber(invoiceNumber);
        invoice.setTotalAmount(booking.getTotalPrice());
        invoice.setStatus(InvoiceStatus.UNPAID);

        Invoice savedInvoice = invoiceRepository.save(invoice);
        booking.setInvoice(savedInvoice);

        return mapToResponse(savedInvoice);
    }

    private String generateInvoiceNumber() {
        int currentYear = LocalDate.now().getYear();
        String prefix = "INV-" + currentYear + "-";
        String maxNumberStr = invoiceRepository.findMaxInvoiceNumberByPrefix(prefix + "%").orElse(prefix + "0000");
        String lastPart = maxNumberStr.substring(prefix.length());
        int nextNumber = Integer.parseInt(lastPart) + 1;
        return prefix + String.format("%04d", nextNumber);
    }

    @Override
    public Page<InvoiceSummaryResponse> getMyInvoices(String currentUserPhone, Pageable pageable) {
        Long userId = userRepository.findByPhone(currentUserPhone).orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND)).getUserId();
        return invoiceRepository.findByBookingUserUserId(userId, pageable).map(this::mapToSummary);
    }

    @Override
    public InvoiceResponse getInvoiceById(Long invoiceId, String currentUserPhone, boolean isAdmin) {
        Invoice invoice = invoiceRepository.findById(invoiceId).orElseThrow(() -> new AppException(ErrorCode.INVOICE_NOT_FOUND, invoiceId));
        if(!isAdmin) {
            Long userId = userRepository.findByPhone(currentUserPhone).orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND)).getUserId();
            if(!invoice.getBooking().getUser().getUserId().equals(userId)){
                throw new AppException(ErrorCode.INVOICE_ACCESS_DENIED);
            }
        }
        return mapToResponse(invoice);
    }

    @Override
    public Page<InvoiceSummaryResponse> getAllInvoices(InvoiceStatus invoiceStatus, Pageable pageable) {
        if (invoiceStatus != null) {
            return invoiceRepository.findByStatus(invoiceStatus, pageable).map(this::mapToSummary);
        }
        return invoiceRepository.findAll(pageable).map(this::mapToSummary);
    }

    private InvoiceResponse mapToResponse(Invoice invoice) {
        Booking booking = invoice.getBooking();
        return new InvoiceResponse(
                invoice.getInvoiceId(),
                invoice.getInvoiceNumber(),
                booking.getBookingId(),
                booking.getUser().getUserId(),
                booking.getUser().getName(),
                booking.getUser().getPhone(),
                booking.getCar().getCarId(),
                booking.getCar().getName(),
                booking.getCar().getBrand(),
                booking.getCar().getLicensePlate(),
                booking.getStartDate(),
                booking.getEndDate(),
                invoice.getTotalAmount(),
                invoice.getStatus(),
                invoice.getPaymentMethod(),
                invoice.getCreateAt(),
                invoice.getUpdateAt()
        );
    }

    private InvoiceSummaryResponse mapToSummary(Invoice invoice) {
        Booking booking = invoice.getBooking();
        return new InvoiceSummaryResponse(
                invoice.getInvoiceId(),
                invoice.getInvoiceNumber(),
                booking.getCar().getName(),
                booking.getCar().getLicensePlate(),
                booking.getStartDate(),
                booking.getEndDate(),
                invoice.getTotalAmount(),
                invoice.getStatus(),
                invoice.getCreateAt()
        );
    }
}

