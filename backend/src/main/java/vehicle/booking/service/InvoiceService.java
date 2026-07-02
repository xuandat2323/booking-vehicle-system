package vehicle.booking.service;

import vehicle.booking.dto.response.InvoiceResponse;
import vehicle.booking.dto.response.InvoiceSummaryResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.enums.InvoiceStatus;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.List;

public interface InvoiceService {
    InvoiceResponse createInvoiceForBooking(Booking booking);
    Page<InvoiceSummaryResponse> getMyInvoices(String currentUserPhone, Pageable pageable);
    InvoiceResponse getInvoiceById(Long invoiceId, String currentUserPhone, boolean isAdmin);
    Page<InvoiceSummaryResponse>  getAllInvoices(InvoiceStatus invoiceStatus, Pageable pageable);
}

