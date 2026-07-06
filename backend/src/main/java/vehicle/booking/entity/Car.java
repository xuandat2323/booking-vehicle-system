package vehicle.booking.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import vehicle.booking.entity.enums.CarStatus;
import vehicle.booking.entity.enums.FuelType;
import vehicle.booking.entity.enums.Transmission;

@Entity
@Table(name = "car")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Car {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "car_id")
    private Long carId;

    @Column(name = "name")
    private String name;

    @Column(name = "brand")
    private String brand;

    @Column(name = "model")
    private String model;

    @Column(name = "license_plate")
    private String licensePlate;

    @Column(name = "price_per_day")
    private BigDecimal pricePerDay;

    @Enumerated(EnumType.STRING)
    @Column(name = "status")
    private CarStatus status;

    @Column(name = "location")
    private String location;

    @Column(name = "latitude", precision = 10, scale = 7)
    private java.math.BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private java.math.BigDecimal longitude;

    @Column(name = "location_source")
    private String locationSource;

    @Column(name = "location_updated_at")
    private LocalDateTime locationUpdatedAt;

    @Column(name = "seats")
    private Integer seats = 5;

    @Enumerated(EnumType.STRING)
    @Column(name = "transmission")
    private Transmission transmission = Transmission.AUTOMATIC;

    @Enumerated(EnumType.STRING)
    @Column(name = "fuel_type")
    private FuelType fuelType = FuelType.GASOLINE;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id")
    private User owner;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "branch_id")
    private Branch branch;

    @OneToMany(mappedBy = "car", fetch = FetchType.LAZY)
    private List<CarImage> images = new ArrayList<>();

    @PreUpdate
    public void preUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
