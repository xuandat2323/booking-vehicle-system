package vehicle.booking.controller.admin;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.PageResponse;
import vehicle.booking.dto.response.UserSummaryResponse;
import vehicle.booking.service.AdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/users")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminUserController {

    private final AdminService adminService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<UserSummaryResponse>>> getAllUsers(
            @RequestParam(defaultValue = "") String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {

        Pageable pageable = PageRequest.of(page, Math.min(size, 50));
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy danh sách người dùng thành công",
                        PageResponse.of(adminService.getAllUsers(search, pageable)))
        );
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<UserSummaryResponse>> getUserById(@PathVariable Long id) {
        return ResponseEntity.ok(
                new ApiResponse<>(true, "Lấy thông tin người dùng thành công",
                        adminService.getUserById(id))
        );
    }

    @PutMapping("/{id}/toggle")
    public ResponseEntity<ApiResponse<Void>> toggleUserStatus(
            @PathVariable Long id,
            @RequestParam boolean enabled) {

        adminService.toggleUserStatus(id, enabled);
        return ResponseEntity.ok(
                new ApiResponse<>(true, enabled ? "Kích hoạt tài khoản thành công" : "Vô hiệu hóa tài khoản thành công", null)
        );
    }
}
