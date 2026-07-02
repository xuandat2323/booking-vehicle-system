package vehicle.booking.controller.admin;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.InvoiceResponse;
import vehicle.booking.dto.response.InvoiceSummaryResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.entity.enums.InvoiceStatus;
import vehicle.booking.service.InvoiceService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin/invoices")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminInvoiceController {
    private final InvoiceService invoiceService;
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<InvoiceSummaryResponse>>> getAllInvoices(
            @RequestParam(required = false)    InvoiceStatus invoiceStatus,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "10") int size) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 50));

        String message = invoiceStatus != null
                ? "Lấy danh sách hoá đơn theo trạng thái " + invoiceStatus + " thành công"
                : "Lấy danh sách tất cả hoá đơn thành công";

        return ResponseEntity.ok(new ApiResponse<>(
                true, message,
                PageResponse.of(invoiceService.getAllInvoices(invoiceStatus, pageable))));
    }
}

