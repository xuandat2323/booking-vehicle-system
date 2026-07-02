package vehicle.booking.service;

import vehicle.booking.dto.response.DashboardStatsResponse;
import vehicle.booking.dto.response.UserSummaryResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface AdminService {

    Page<UserSummaryResponse> getAllUsers(String search, Pageable pageable);

    UserSummaryResponse getUserById(Long userId);

    void toggleUserStatus(Long userId, boolean enabled);

    DashboardStatsResponse getDashboardStats();
}
