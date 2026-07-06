package vehicle.booking.service;

import vehicle.booking.dto.response.BranchResponse;

import java.util.List;

public interface BranchService {
    List<BranchResponse> getActiveBranches();
    BranchResponse getBranchById(Long branchId);
    BranchResponse createBranch(String name, String address, String phone,
                                java.math.BigDecimal latitude, java.math.BigDecimal longitude);
    BranchResponse updateBranch(Long branchId, String name, String address, String phone,
                                java.math.BigDecimal latitude, java.math.BigDecimal longitude, Boolean isActive);
    void deleteBranch(Long branchId);
}
