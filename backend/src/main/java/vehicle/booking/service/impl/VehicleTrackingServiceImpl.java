package vehicle.booking.service.impl;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vehicle.booking.dto.request.VehicleTrackingUpdateRequest;
import vehicle.booking.dto.response.VehicleTrackingHistoryResponse;
import vehicle.booking.dto.response.VehicleTrackingResponse;
import vehicle.booking.entity.Car;
import vehicle.booking.entity.VehicleTrackingLocation;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.CarRepository;
import vehicle.booking.repository.VehicleTrackingLocationRepository;
import vehicle.booking.service.VehicleTrackingService;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class VehicleTrackingServiceImpl implements VehicleTrackingService {

    private final VehicleTrackingLocationRepository trackingRepository;
    private final CarRepository carRepository;

    @Override
    @Transactional
    public VehicleTrackingResponse updateCurrentLocation(Long carId, VehicleTrackingUpdateRequest request) {
        Car car = carRepository.findById(carId)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, carId));

        trackingRepository.findByCarCarIdOrderByUpdatedAtDesc(carId)
                .forEach(item -> item.setCurrent(false));

        VehicleTrackingLocation tracking = new VehicleTrackingLocation();
        tracking.setCar(car);
        tracking.setLatitude(request.latitude());
        tracking.setLongitude(request.longitude());
        tracking.setSpeedKmh(request.speedKmh());
        tracking.setHeading(request.heading());
        tracking.setAddress(request.address());
        tracking.setSource(request.source());
        tracking.setCurrent(true);

        VehicleTrackingLocation saved = trackingRepository.save(tracking);
        car.setLatitude(request.latitude());
        car.setLongitude(request.longitude());
        car.setLocation(request.address() != null ? request.address() : car.getLocation());
        car.setLocationSource(request.source());
        car.setLocationUpdatedAt(saved.getUpdatedAt());
        carRepository.save(car);

        return toResponse(saved);
    }

    @Override
    public VehicleTrackingResponse getCurrentLocation(Long carId) {
        VehicleTrackingLocation current = trackingRepository
                .findFirstByCarCarIdAndCurrentTrueOrderByUpdatedAtDesc(carId)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, carId));
        return toResponse(current);
    }

    @Override
    public List<VehicleTrackingHistoryResponse> getTrackingHistory(Long carId) {
        return trackingRepository.findByCarCarIdOrderByUpdatedAtDesc(carId).stream()
                .map(this::toHistoryResponse)
                .toList();
    }

    private VehicleTrackingResponse toResponse(VehicleTrackingLocation tracking) {
        return new VehicleTrackingResponse(
                tracking.getCar().getCarId(),
                tracking.getLatitude(),
                tracking.getLongitude(),
                tracking.getSpeedKmh(),
                tracking.getHeading(),
                tracking.getAddress(),
                tracking.getSource(),
                tracking.getUpdatedAt()
        );
    }

    private VehicleTrackingHistoryResponse toHistoryResponse(VehicleTrackingLocation tracking) {
        return new VehicleTrackingHistoryResponse(
                tracking.getTrackingLocationId(),
                tracking.getCar().getCarId(),
                tracking.getLatitude(),
                tracking.getLongitude(),
                tracking.getSpeedKmh(),
                tracking.getHeading(),
                tracking.getAddress(),
                tracking.getSource(),
                tracking.getUpdatedAt(),
                tracking.getCurrent()
        );
    }
}
