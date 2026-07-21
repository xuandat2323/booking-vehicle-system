package vehicle.booking.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import vehicle.booking.entity.Car;
import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

public interface CarRepository extends JpaRepository<Car, Long> {
    Optional<Car> findByLicensePlate(String licensePlate);

    List<Car> findByStatus(CarStatus status);
    Page<Car> findByStatus(CarStatus status, Pageable pageable);

    List<Car> findByBrandContainingIgnoreCase(String brand);

    boolean existsByLicensePlate(String licensePlate);

    @Query("""
    SELECT c FROM Car c
    WHERE c.latitude IS NOT NULL
      AND c.longitude IS NOT NULL
      AND c.latitude  BETWEEN :minLat AND :maxLat
      AND c.longitude BETWEEN :minLng AND :maxLng
      AND (:onlyAvailable = false OR c.status = 'AVAILABLE')
      AND (:branchId IS NULL OR c.branch.branchId = :branchId)
    """)
    List<Car> findNearby(
            @Param("minLat") BigDecimal minLat,
            @Param("maxLat") BigDecimal maxLat,
            @Param("minLng") BigDecimal minLng,
            @Param("maxLng") BigDecimal maxLng,
            @Param("onlyAvailable") boolean onlyAvailable,
            @Param("branchId") Long branchId
    );

    @Query("""
    SELECT c FROM Car c
    WHERE (:brand IS NULL OR LOWER(c.brand) LIKE LOWER(CONCAT('%', :brand, '%')))
      AND (:name IS NULL OR LOWER(c.name) LIKE LOWER(CONCAT('%', :name, '%')))
      AND (:location IS NULL OR LOWER(c.location) LIKE LOWER(CONCAT('%', :location, '%')))
      AND (:transmission IS NULL OR c.transmission = :transmission)
      AND (:fuelType IS NULL OR c.fuelType = :fuelType)
      AND (:minPrice IS NULL OR c.pricePerDay >= :minPrice)
      AND (:maxPrice IS NULL OR c.pricePerDay <= :maxPrice)
      AND (:filterBySeats = false OR c.seats IN :seats)
      AND (:onlyAvailable = false OR c.status = 'AVAILABLE')
      AND (:branchId IS NULL OR c.branch.branchId = :branchId)
    """)
    Page<Car> findWithFilters(
            @Param("brand")         String brand,
            @Param("name")          String name,
            @Param("location")      String location,
            @Param("transmission")  Transmission transmission,
            @Param("fuelType")      FuelType fuelType,
            @Param("minPrice")      BigDecimal minPrice,
            @Param("maxPrice")      BigDecimal maxPrice,
            @Param("filterBySeats") boolean filterBySeats,
            @Param("seats")         List<Integer> seats,
            @Param("onlyAvailable") boolean onlyAvailable,
            @Param("branchId")      Long branchId,
            Pageable pageable
    );

    Page<Car> findByBranchBranchId(Long branchId, Pageable pageable);

    Page<Car> findByOwnerUserId(Long ownerId, Pageable pageable);

    @Query("""
    SELECT c FROM Car c
    WHERE c.owner.userId = :ownerId
      AND (:status IS NULL OR c.status = :status)
    """)
    Page<Car> findByOwnerUserIdAndStatus(
            @Param("ownerId") Long ownerId,
            @Param("status") CarStatus status,
            Pageable pageable
    );
}

