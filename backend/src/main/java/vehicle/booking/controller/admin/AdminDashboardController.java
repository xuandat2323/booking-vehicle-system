package vehicle.booking.controller.admin;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.DashboardStatsResponse;
import vehicle.booking.service.AdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/dashboard")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminDashboardController {

    private final AdminService adminService;

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<DashboardStatsResponse>> getDashboardStats() {
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy thống kê dashboard thành công",
                        adminService.getDashboardStats())
        );
    }
}
