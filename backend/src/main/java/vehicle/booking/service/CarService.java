package vehicle.booking.service;

import vehicle.booking.dto.request.CarCreateRequest;
import vehicle.booking.dto.request.CarUpdateRequest;
import vehicle.booking.dto.response.CarAvailabilityResponse;
import vehicle.booking.dto.response.CarResponse;
import vehicle.booking.dto.response.CarSummaryResponse;
import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.util.List;

public interface CarService {

    CarResponse createCar(CarCreateRequest request);

    CarResponse updateCar(Long id, CarUpdateRequest request);

    void deleteCar(Long id);

    CarResponse getCarById(Long id);

    Page<CarSummaryResponse> getAllCars(boolean onlyAvailable, Pageable pageable);

    Page<CarSummaryResponse> searchCars(
            boolean onlyAvailable,
            String brand,
            String name,
            String location,
            Transmission transmission,
            FuelType fuelType,
            BigDecimal minPrice,
            BigDecimal maxPrice,
            List<Integer> seats,
            Pageable pageable
    );

    CarAvailabilityResponse getCarAvailability(Long carId);

    CarResponse updateCarLocation(Long carId, vehicle.booking.dto.request.CarLocationUpdateRequest request);

    List<CarSummaryResponse> getNearbyCars(Double lat, Double lng, Double radiusKm, boolean onlyAvailable);

    // Owner-facing methods
    vehicle.booking.dto.response.CarResponse createCarByOwner(vehicle.booking.dto.request.CarCreateRequest request, String ownerPhone);
    org.springframework.data.domain.Page<vehicle.booking.dto.response.CarSummaryResponse> getMyOwnerCars(String ownerPhone, org.springframework.data.domain.Pageable pageable);
    vehicle.booking.dto.response.CarResponse updateCarByOwner(Long carId, vehicle.booking.dto.request.CarUpdateRequest request, String ownerPhone);
    void deleteCarByOwner(Long carId, String ownerPhone);
}
