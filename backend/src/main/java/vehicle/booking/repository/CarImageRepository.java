package vehicle.booking.repository;

import vehicle.booking.entity.CarImage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CarImageRepository extends JpaRepository<CarImage, Long> {

    long countByCarCarId(Long carId);

    @Query("""
    select ci from CarImage ci
    where ci.car.carId = :carId
    order by ci.sortOrder asc, ci.createdAt asc
            """)
    List<CarImage> findByCarIdOrderBySortThenCreatedAt(@Param("carId") Long carId);

    @Modifying
    @Query("""
    update CarImage ci
    set ci.isPrimary = false
    where ci.car.carId = :carId
      and ci.isPrimary = true
    """)
    int clearPrimaryByCarId(@Param("carId") Long carId);

    @Query("""
    select max(ci.sortOrder) from CarImage ci
    where ci.car.carId = :carId
    """)
    Optional<Integer> findMaxSortOrderByCarId(@Param("carId") Long carId);

    @Query("""
    select ci from CarImage ci
    where ci.carImageId = :carImageId
    and ci.car.carId = :carId
    """)
    Optional<CarImage> findByCarImageIdAndCarCarId(@Param("carImageId") Long carImageId, @Param("carId") Long carId);

    Optional<CarImage> findByCarCarIdAndIsPrimaryTrue(Long carId);

    List<CarImage> findByCarCarIdInAndIsPrimaryTrue(List<Long> carIds);
}
