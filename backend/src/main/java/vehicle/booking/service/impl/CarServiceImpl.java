package vehicle.booking.service.impl;

import vehicle.booking.dto.request.CarCreateRequest;
import vehicle.booking.dto.request.CarLocationUpdateRequest;
import vehicle.booking.dto.request.CarUpdateRequest;
import vehicle.booking.dto.response.CarAvailabilityResponse;
import vehicle.booking.dto.response.CarResponse;
import vehicle.booking.dto.response.CarSummaryResponse;
import vehicle.booking.entity.Booking;
import vehicle.booking.entity.Car;
import vehicle.booking.entity.CarImage;
import vehicle.booking.entity.enums.BookingStatus;
import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.BookingRepository;
import vehicle.booking.repository.CarImageRepository;
import vehicle.booking.repository.CarRepository;
import vehicle.booking.service.CarService;
import vehicle.booking.entity.User;
import vehicle.booking.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Triển khai dịch vụ Quản lý Xe (Cars).
 * Chịu trách nhiệm:
 * 1. CRUD thông tin xe.
 * 2. Tìm kiếm xe với bộ lọc đa điều kiện (Hãng, Giá, Chỗ ngồi, Hộp số...).
 * 3. Quản lý hình ảnh và trạng thái của xe.
 * 4. Tích hợp lấy điểm đánh giá trung bình cho từng xe.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CarServiceImpl implements CarService {

    private static final Set<Integer> SUPPORTED_SEATS = Set.of(4, 5, 7, 8, 9);
    private static final int DEFAULT_SEATS = 5;
    private static final Transmission DEFAULT_TRANSMISSION = Transmission.AUTOMATIC;
    private static final FuelType DEFAULT_FUEL_TYPE = FuelType.GASOLINE;

    private final CarRepository carRepository;
    private final BookingRepository bookingRepository;
    private final CarImageRepository carImageRepository;
    private final vehicle.booking.repository.ReviewRepository reviewRepository;
    private final UserRepository userRepository;

    @Override
    @Transactional
    public CarResponse createCar(CarCreateRequest request) {
        if (carRepository.existsByLicensePlate(request.licensePlate())) {
            throw new AppException(ErrorCode.CAR_LICENSE_PLATE_EXISTS, request.licensePlate());
        }

        Car car = new Car();
        car.setName(request.name());
        car.setBrand(request.brand());
        car.setModel(request.model());
        car.setLicensePlate(request.licensePlate());
        car.setPricePerDay(request.pricePerDay());
        car.setStatus(request.carStatus() != null ? request.carStatus() : CarStatus.AVAILABLE);
        car.setSeats(Objects.requireNonNullElse(request.seats(), DEFAULT_SEATS));
        car.setTransmission(Objects.requireNonNullElse(request.transmission(), DEFAULT_TRANSMISSION));
        car.setFuelType(Objects.requireNonNullElse(request.fuelType(), DEFAULT_FUEL_TYPE));
        car.setLocation(request.location());

        Car saved = carRepository.save(car);
        return mapToResponse(saved, null);
    }

    @Override
    @Transactional
    public CarResponse updateCar(Long id, CarUpdateRequest request) {
        Car car = carRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND,id));

        if (request.licensePlate() != null && !request.licensePlate().equals(car.getLicensePlate())) {
            if (carRepository.existsByLicensePlate(request.licensePlate())) {
                throw new AppException(ErrorCode.CAR_LICENSE_PLATE_EXISTS, request.licensePlate());
            }
            car.setLicensePlate(request.licensePlate());
        }

        if (request.name() != null) car.setName(request.name());
        if (request.brand() != null) car.setBrand(request.brand());
        if (request.model() != null) car.setModel(request.model());
        if (request.pricePerDay() != null) car.setPricePerDay(request.pricePerDay());
        if (request.status() != null) car.setStatus(request.status());
        if (request.seats() != null) car.setSeats(request.seats());
        if (request.transmission() != null) car.setTransmission(request.transmission());
        if (request.fuelType() != null) car.setFuelType(request.fuelType());
        if (request.location() != null) car.setLocation(request.location());

        Car updated = carRepository.save(car);
        String primaryImageUrl = resolvePrimaryImageUrl(updated.getCarId());
        return mapToResponse(updated, primaryImageUrl);
    }

    @Override
    @Transactional
    public void deleteCar(Long id) {
        Car car = carRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, id));

        car.setStatus(CarStatus.DISABLED);
        carRepository.save(car);
    }

    @Override
    public CarResponse getCarById(Long id) {
        Car car = carRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, id));
        String primaryImageUrl = resolvePrimaryImageUrl(car.getCarId());
        return mapToResponse(car, primaryImageUrl);
    }

    @Override
    public Page<CarSummaryResponse> getAllCars(boolean onlyAvailable, Pageable pageable) {
        Page<Car> carPage = onlyAvailable
                ? carRepository.findByStatus(CarStatus.AVAILABLE, pageable)
                : carRepository.findAll(pageable);
        return toSummaryPage(carPage);
    }

    /**
     * Tìm kiếm xe nâng cao.
     * Sử dụng Query trong Repository để tìm kiếm linh hoạt theo nhiều tiêu chí.
     * Hỗ trợ phân trang và lọc chỉ lấy xe đang sẵn sàng (AVAILABLE).
     */
    @Override
    public Page<CarSummaryResponse> searchCars(
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
    ) {
        validateSearchFilters(minPrice, maxPrice, seats);

        List<Integer> normalizedSeats = normalizeSeats(seats);
        boolean filterBySeats = !normalizedSeats.isEmpty();
        List<Integer> seatsForQuery = filterBySeats ? normalizedSeats : List.copyOf(SUPPORTED_SEATS);

        Page<Car> carPage = carRepository.findWithFilters(
                        normalizeText(brand),
                        normalizeText(name),
                        normalizeText(location),
                        transmission,
                        fuelType,
                        minPrice,
                        maxPrice,
                        filterBySeats,
                        seatsForQuery,
                        onlyAvailable,
                        pageable
                );
        return toSummaryPage(carPage);
    }

    @Override
    public CarAvailabilityResponse getCarAvailability(Long carId) {
        Car car = carRepository.findById(carId).orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, carId));
        LocalDate today = LocalDate.now();
        List<Booking> activeBookings = bookingRepository.findActiveBookingsByCarId(carId, today, List.of(BookingStatus.PENDING, BookingStatus.COMPLETED));
        List<LocalDate> bookedDates = activeBookings.stream()
                .flatMap(booking -> booking.getStartDate()
                        .datesUntil(booking.getEndDate().plusDays(1)))
                .filter(localDate -> !localDate.isBefore(today))
                .distinct()
                .sorted()
                .collect(Collectors.toList());

        return new CarAvailabilityResponse(
                car.getCarId(),
                car.getName(),
                car.getLicensePlate(),
                bookedDates
        );
    }

    @Override
    @Transactional
    public CarResponse updateCarLocation(Long carId, CarLocationUpdateRequest request) {
        Car car = carRepository.findById(carId)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, carId));
        car.setLatitude(request.latitude());
        car.setLongitude(request.longitude());
        if (request.address() != null) {
            car.setLocation(request.address());
        }
        car.setLocationSource(request.source());
        car.setLocationUpdatedAt(java.time.LocalDateTime.now());
        Car saved = carRepository.save(car);
        return mapToResponse(saved, resolvePrimaryImageUrl(saved.getCarId()));
    }

    private CarResponse mapToResponse(Car car, String imageUrl) {
        Double avgRating = reviewRepository.getAverageRatingByCarId(car.getCarId());
        Long reviewCount = reviewRepository.countByCarId(car.getCarId());
        
        return new CarResponse(
                car.getCarId(),
                car.getName(),
                car.getBrand(),
                car.getModel(),
                car.getLicensePlate(),
                car.getPricePerDay(),
                car.getStatus(),
                imageUrl,
                car.getSeats(),
                car.getTransmission(),
                car.getFuelType(),
                car.getLocation(),
                car.getLatitude(),
                car.getLongitude(),
                car.getLocationSource(),
                car.getLocationUpdatedAt(),
                car.getCreatedAt(),
                car.getUpdatedAt(),
                avgRating != null ? avgRating : 0.0,
                reviewCount != null ? reviewCount : 0L
        );
    }

    private CarSummaryResponse mapToSummary(Car car, String imageUrl) {
        Double avgRating = reviewRepository.getAverageRatingByCarId(car.getCarId());
        Long reviewCount = reviewRepository.countByCarId(car.getCarId());
        
        return new CarSummaryResponse(
                car.getCarId(),
                car.getName(),
                car.getBrand(),
                car.getLicensePlate(),
                car.getPricePerDay(),
                car.getStatus(),
                imageUrl,
                car.getSeats(),
                car.getLocation(),
                car.getLatitude(),
                car.getLongitude(),
                avgRating != null ? avgRating : 0.0,
                reviewCount != null ? reviewCount : 0L
        );
    }

    private Page<CarSummaryResponse> toSummaryPage(Page<Car> carPage) {
        Map<Long, String> primaryImageUrls = resolvePrimaryImageUrls(carPage.getContent());
        List<CarSummaryResponse> content = carPage.getContent().stream()
                .map(car -> mapToSummary(car, primaryImageUrls.get(car.getCarId())))
                .toList();
        return new PageImpl<>(content, carPage.getPageable(), carPage.getTotalElements());
    }

    private String resolvePrimaryImageUrl(Long carId) {
        return carImageRepository.findByCarCarIdAndIsPrimaryTrue(carId)
                .map(CarImage::getImageUrl)
                .orElse(null);
    }

    private Map<Long, String> resolvePrimaryImageUrls(List<Car> cars) {
        if (cars == null || cars.isEmpty()) {
            return Map.of();
        }
        List<Long> carIds = cars.stream()
                .map(Car::getCarId)
                .toList();
        return carImageRepository.findByCarCarIdInAndIsPrimaryTrue(carIds).stream()
                .collect(Collectors.toMap(
                        image -> image.getCar().getCarId(),
                        CarImage::getImageUrl,
                        (existing, ignored) -> existing
                ));
    }

    @Override
    public List<CarSummaryResponse> getNearbyCars(Double lat, Double lng, Double radiusKm, boolean onlyAvailable) {
        double delta = radiusKm / 111.0;
        double lngDelta = radiusKm / (111.0 * Math.cos(Math.toRadians(lat)));

        BigDecimal minLat = BigDecimal.valueOf(lat - delta);
        BigDecimal maxLat = BigDecimal.valueOf(lat + delta);
        BigDecimal minLng = BigDecimal.valueOf(lng - lngDelta);
        BigDecimal maxLng = BigDecimal.valueOf(lng + lngDelta);

        List<Car> cars = carRepository.findNearby(minLat, maxLat, minLng, maxLng, onlyAvailable);
        Map<Long, String> imageUrls = resolvePrimaryImageUrls(cars);
        return cars.stream()
                .map(car -> mapToSummary(car, imageUrls.get(car.getCarId())))
                .toList();
    }

    private String normalizeText(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    private List<Integer> normalizeSeats(List<Integer> seats) {
        if (seats == null || seats.isEmpty()) {
            return List.of();
        }
        return new LinkedHashSet<>(seats).stream()
                .filter(value -> value != null)
                .toList();
    }

    private void validateSearchFilters(
            BigDecimal minPrice,
            BigDecimal maxPrice,
            List<Integer> seats
    ) {
        if (minPrice != null && minPrice.signum() < 0) {
            throw new AppException(ErrorCode.CAR_FILTER_INVALID_PRICE_RANGE);
        }
        if (maxPrice != null && maxPrice.signum() < 0) {
            throw new AppException(ErrorCode.CAR_FILTER_INVALID_PRICE_RANGE);
        }
        if (minPrice != null && maxPrice != null && minPrice.compareTo(maxPrice) > 0) {
            throw new AppException(ErrorCode.CAR_FILTER_INVALID_PRICE_RANGE);
        }

        List<Integer> normalizedSeats = normalizeSeats(seats);
        if (!normalizedSeats.stream().allMatch(SUPPORTED_SEATS::contains)) {
            throw new AppException(ErrorCode.CAR_FILTER_INVALID_SEATS);
        }
    }

    @Override
    @Transactional
    public CarResponse createCarByOwner(CarCreateRequest request, String ownerPhone) {
        if (carRepository.existsByLicensePlate(request.licensePlate())) {
            throw new AppException(ErrorCode.CAR_LICENSE_PLATE_EXISTS, request.licensePlate());
        }
        User owner = userRepository.findByPhone(ownerPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Car car = new Car();
        car.setName(request.name());
        car.setBrand(request.brand());
        car.setModel(request.model());
        car.setLicensePlate(request.licensePlate());
        car.setPricePerDay(request.pricePerDay());
        car.setStatus(CarStatus.AVAILABLE);
        car.setSeats(Objects.requireNonNullElse(request.seats(), DEFAULT_SEATS));
        car.setTransmission(Objects.requireNonNullElse(request.transmission(), DEFAULT_TRANSMISSION));
        car.setFuelType(Objects.requireNonNullElse(request.fuelType(), DEFAULT_FUEL_TYPE));
        car.setLocation(request.location());
        car.setOwner(owner);

        Car saved = carRepository.save(car);
        return mapToResponse(saved, null);
    }

    @Override
    public Page<CarSummaryResponse> getMyOwnerCars(String ownerPhone, Pageable pageable) {
        User owner = userRepository.findByPhone(ownerPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        Page<Car> page = carRepository.findByOwnerUserId(owner.getUserId(), pageable);
        return toSummaryPage(page);
    }

    @Override
    @Transactional
    public CarResponse updateCarByOwner(Long carId, CarUpdateRequest request, String ownerPhone) {
        Car car = carRepository.findById(carId)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, carId));
        User owner = userRepository.findByPhone(ownerPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        if (car.getOwner() == null || !car.getOwner().getUserId().equals(owner.getUserId())) {
            throw new AppException(ErrorCode.CAR_NOT_OWNER);
        }

        if (request.licensePlate() != null && !request.licensePlate().equals(car.getLicensePlate())) {
            if (carRepository.existsByLicensePlate(request.licensePlate())) {
                throw new AppException(ErrorCode.CAR_LICENSE_PLATE_EXISTS, request.licensePlate());
            }
            car.setLicensePlate(request.licensePlate());
        }
        if (request.name() != null) car.setName(request.name());
        if (request.brand() != null) car.setBrand(request.brand());
        if (request.model() != null) car.setModel(request.model());
        if (request.pricePerDay() != null) car.setPricePerDay(request.pricePerDay());
        if (request.seats() != null) car.setSeats(request.seats());
        if (request.transmission() != null) car.setTransmission(request.transmission());
        if (request.fuelType() != null) car.setFuelType(request.fuelType());
        if (request.location() != null) car.setLocation(request.location());

        Car updated = carRepository.save(car);
        return mapToResponse(updated, resolvePrimaryImageUrl(updated.getCarId()));
    }

    @Override
    @Transactional
    public void deleteCarByOwner(Long carId, String ownerPhone) {
        Car car = carRepository.findById(carId)
                .orElseThrow(() -> new AppException(ErrorCode.CAR_NOT_FOUND, carId));
        User owner = userRepository.findByPhone(ownerPhone)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        if (car.getOwner() == null || !car.getOwner().getUserId().equals(owner.getUserId())) {
            throw new AppException(ErrorCode.CAR_NOT_OWNER);
        }
        car.setStatus(CarStatus.DISABLED);
        carRepository.save(car);
    }
}

