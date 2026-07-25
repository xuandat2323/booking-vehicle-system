package vehicle.booking.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BranchResponse {
    private Long branchId;
    private String name;
    private String address;
    private String phone;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private Boolean isActive;
    private Long availableCarCount;
    /// Xe đang có khách thuê (BOOKED) hoặc vừa được đặt chờ cọc (PENDING).
    private Long rentedCarCount;
    private Long maintenanceCarCount;
    private Long totalCarCount;
}
