package vehicle.booking.repository;

import vehicle.booking.entity.VehicleTrackingLocation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface VehicleTrackingLocationRepository extends JpaRepository<VehicleTrackingLocation, Long> {
    Optional<VehicleTrackingLocation> findFirstByCarCarIdAndCurrentTrueOrderByUpdatedAtDesc(Long carId);

    List<VehicleTrackingLocation> findByCarCarIdOrderByUpdatedAtDesc(Long carId);

    Page<VehicleTrackingLocation> findByCarCarIdOrderByUpdatedAtDesc(Long carId, Pageable pageable);
}
