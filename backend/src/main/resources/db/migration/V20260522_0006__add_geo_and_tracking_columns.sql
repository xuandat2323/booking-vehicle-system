ALTER TABLE car
    ADD COLUMN latitude DECIMAL(10,7) NULL,
    ADD COLUMN longitude DECIMAL(10,7) NULL,
    ADD COLUMN location_source VARCHAR(100) NULL,
    ADD COLUMN location_updated_at DATETIME NULL;

ALTER TABLE booking
    ADD COLUMN pickup_address VARCHAR(255) NULL,
    ADD COLUMN pickup_latitude DECIMAL(10,7) NULL,
    ADD COLUMN pickup_longitude DECIMAL(10,7) NULL,
    ADD COLUMN dropoff_address VARCHAR(255) NULL,
    ADD COLUMN dropoff_latitude DECIMAL(10,7) NULL,
    ADD COLUMN dropoff_longitude DECIMAL(10,7) NULL;

CREATE TABLE IF NOT EXISTS vehicle_tracking_location (
    tracking_location_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    car_id BIGINT NOT NULL,
    latitude DECIMAL(10,7) NULL,
    longitude DECIMAL(10,7) NULL,
    speed_kmh DECIMAL(8,2) NULL,
    heading INT NULL,
    address VARCHAR(255) NULL,
    source VARCHAR(100) NULL,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_vehicle_tracking_car FOREIGN KEY (car_id) REFERENCES car(car_id)
);

CREATE INDEX idx_vehicle_tracking_car_current ON vehicle_tracking_location(car_id, is_current, updated_at);
CREATE INDEX idx_vehicle_tracking_car_updated ON vehicle_tracking_location(car_id, updated_at);
