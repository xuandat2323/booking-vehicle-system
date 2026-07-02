package vehicle.booking.controller;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.InvoiceResponse;
import vehicle.booking.dto.response.InvoiceSummaryResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.service.InvoiceService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/invoices")
@RequiredArgsConstructor
@PreAuthorize("hasRole('USER')")
public class InvoiceController {
    private final InvoiceService invoiceService;

    @GetMapping("/my-invoices")
    public ResponseEntity<ApiResponse<PageResponse<InvoiceSummaryResponse>>> getMyInvoices(
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "10") int size,
            Authentication authentication) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 50));

        return ResponseEntity.ok(new ApiResponse<>(
                true,
                "Lấy danh sách hoá đơn của bạn thành công",
                PageResponse.of(invoiceService.getMyInvoices(authentication.getName(), pageable))));
    }

    @GetMapping("{id}")
    public ResponseEntity<ApiResponse<InvoiceResponse>> getInvoiceById(@PathVariable Long id, Authentication authentication) {
        String currentUserPhone = authentication.getName();
        boolean isAdmin = false;
        InvoiceResponse invoice = invoiceService.getInvoiceById(id, currentUserPhone, isAdmin);
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy chi tiết hoá đơn thành công", invoice));
    }
}
