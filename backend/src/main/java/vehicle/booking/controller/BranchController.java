package vehicle.booking.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.dto.response.BranchResponse;
import vehicle.booking.service.BranchService;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/branches")
@RequiredArgsConstructor
public class BranchController {

    private final BranchService branchService;

    /**
     * Public: Lấy danh sách cơ sở đang hoạt động
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<BranchResponse>>> getActiveBranches() {
        List<BranchResponse> branches = branchService.getActiveBranches();
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy danh sách cơ sở thành công", branches));
    }

    /**
     * Public: Lấy chi tiết cơ sở
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<BranchResponse>> getBranchById(@PathVariable Long id) {
        BranchResponse branch = branchService.getBranchById(id);
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy chi tiết cơ sở thành công", branch));
    }

    /**
     * Admin only: Tạo cơ sở mới
     */
    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<BranchResponse>> createBranch(@RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        String address = (String) body.get("address");
        String phone = (String) body.get("phone");
        BigDecimal latitude = body.get("latitude") != null ? new BigDecimal(body.get("latitude").toString()) : null;
        BigDecimal longitude = body.get("longitude") != null ? new BigDecimal(body.get("longitude").toString()) : null;
        BranchResponse branch = branchService.createBranch(name, address, phone, latitude, longitude);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(true, "Tạo cơ sở thành công", branch));
    }

    /**
     * Admin only: Cập nhật cơ sở
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<BranchResponse>> updateBranch(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        String address = (String) body.get("address");
        String phone = (String) body.get("phone");
        BigDecimal latitude = body.get("latitude") != null ? new BigDecimal(body.get("latitude").toString()) : null;
        BigDecimal longitude = body.get("longitude") != null ? new BigDecimal(body.get("longitude").toString()) : null;
        Boolean isActive = body.get("isActive") != null ? (Boolean) body.get("isActive") : null;
        BranchResponse branch = branchService.updateBranch(id, name, address, phone, latitude, longitude, isActive);
        return ResponseEntity.ok(new ApiResponse<>(true, "Cập nhật cơ sở thành công", branch));
    }

    /**
     * Admin only: Vô hiệu hóa cơ sở
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteBranch(@PathVariable Long id) {
        branchService.deleteBranch(id);
        return ResponseEntity.ok(new ApiResponse<>(true, "Vô hiệu hóa cơ sở thành công", null));
    }
}
