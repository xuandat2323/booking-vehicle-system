package vehicle.booking.service.impl;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vehicle.booking.dto.response.BranchResponse;
import vehicle.booking.entity.Branch;
import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BranchRepository;
import vehicle.booking.service.BranchService;

import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BranchServiceImpl implements BranchService {

    private final BranchRepository branchRepository;

    @Override
    public List<BranchResponse> getActiveBranches() {
        return branchRepository.findByIsActiveTrue().stream()
                .map(this::mapToResponse)
                .toList();
    }

    @Override
    public BranchResponse getBranchById(Long branchId) {
        Branch branch = branchRepository.findById(branchId)
                .orElseThrow(() -> new AppException(ErrorCode.RESOURCE_NOT_FOUND, "Branch", branchId));
        return mapToResponse(branch);
    }

    @Override
    @Transactional
    public BranchResponse createBranch(String name, String address, String phone,
                                       BigDecimal latitude, BigDecimal longitude) {
        Branch branch = new Branch();
        branch.setName(name);
        branch.setAddress(address);
        branch.setPhone(phone);
        branch.setLatitude(latitude);
        branch.setLongitude(longitude);
        branch.setIsActive(true);
        Branch saved = branchRepository.save(branch);
        return mapToResponse(saved);
    }

    @Override
    @Transactional
    public BranchResponse updateBranch(Long branchId, String name, String address, String phone,
                                       BigDecimal latitude, BigDecimal longitude, Boolean isActive) {
        Branch branch = branchRepository.findById(branchId)
                .orElseThrow(() -> new AppException(ErrorCode.RESOURCE_NOT_FOUND, "Branch", branchId));
        if (name != null) branch.setName(name);
        if (address != null) branch.setAddress(address);
        if (phone != null) branch.setPhone(phone);
        if (latitude != null) branch.setLatitude(latitude);
        if (longitude != null) branch.setLongitude(longitude);
        if (isActive != null) branch.setIsActive(isActive);
        Branch saved = branchRepository.save(branch);
        return mapToResponse(saved);
    }

    @Override
    @Transactional
    public void deleteBranch(Long branchId) {
        Branch branch = branchRepository.findById(branchId)
                .orElseThrow(() -> new AppException(ErrorCode.RESOURCE_NOT_FOUND, "Branch", branchId));
        branch.setIsActive(false);
        branchRepository.save(branch);
    }

    private BranchResponse mapToResponse(Branch branch) {
        long availableCount = branch.getCars() != null
                ? branch.getCars().stream()
                    .filter(car -> car.getStatus() == CarStatus.AVAILABLE)
                    .count()
                : 0L;
        return BranchResponse.builder()
                .branchId(branch.getBranchId())
                .name(branch.getName())
                .address(branch.getAddress())
                .phone(branch.getPhone())
                .latitude(branch.getLatitude())
                .longitude(branch.getLongitude())
                .isActive(branch.getIsActive())
                .availableCarCount(availableCount)
                .build();
    }
}
