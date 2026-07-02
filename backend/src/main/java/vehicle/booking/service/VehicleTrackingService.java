package vehicle.booking.service;

import vehicle.booking.dto.request.VehicleTrackingUpdateRequest;
import vehicle.booking.dto.response.VehicleTrackingHistoryResponse;
import vehicle.booking.dto.response.VehicleTrackingResponse;

import java.util.List;

public interface VehicleTrackingService {
    VehicleTrackingResponse updateCurrentLocation(Long carId, VehicleTrackingUpdateRequest request);

    VehicleTrackingResponse getCurrentLocation(Long carId);

    List<VehicleTrackingHistoryResponse> getTrackingHistory(Long carId);
}
