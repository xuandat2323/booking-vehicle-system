-- Seed Users
INSERT INTO users (name, email, password, phone, role) VALUES
('Admin AutoRent', 'admin@autorent.com', '$2a$10$moAvhjGMF/bmSSW486th8OA0sRQUse0jUGHX5ReeaktPOkkyZus1a', '+84987654321', 'ADMIN'),
('Nguyễn Văn Khách', 'user@gmail.com', '$2a$10$moAvhjGMF/bmSSW486th8OA0sRQUse0jUGHX5ReeaktPOkkyZus1a', '+84123456789', 'USER');

-- Seed Cars
INSERT INTO car (name, brand, model, license_plate, price_per_day, status, location, seats, transmission, fuel_type) VALUES 
('VinFast VF8', 'VinFast', 'Plus', '30K-123.45', 1200000, 'AVAILABLE', 'Hà Nội', 5, 'AUTOMATIC', 'ELECTRIC'),
('Toyota Camry', 'Toyota', '2.5Q', '51G-999.99', 1500000, 'AVAILABLE', 'TP. Hồ Chí Minh', 5, 'AUTOMATIC', 'GASOLINE'),
('Mazda CX-5', 'Mazda', 'Premium', '43A-555.55', 1000000, 'AVAILABLE', 'Đà Nẵng', 5, 'AUTOMATIC', 'GASOLINE'),
('Ford Ranger', 'Ford', 'Wildtrak', '29H-888.88', 1300000, 'AVAILABLE', 'Hà Nội', 5, 'AUTOMATIC', 'DIESEL'),
('Mitsubishi Xpander', 'Mitsubishi', 'Cross', '60A-777.77', 800000, 'AVAILABLE', 'Bình Dương', 7, 'AUTOMATIC', 'GASOLINE');

-- Seed initial images for cars (using placeholder URLs)
INSERT INTO car_image (car_id, image_url, public_id, format, is_primary, created_at, updated_at) VALUES 
(1, 'https://res.cloudinary.com/dudtaz1xg/image/upload/v1715155200/vehicle-booking/cars/vf8.jpg', 'seed_vf8', 'jpg', 1, NOW(), NOW()),
(2, 'https://res.cloudinary.com/dudtaz1xg/image/upload/v1715155200/vehicle-booking/cars/camry.jpg', 'seed_camry', 'jpg', 1, NOW(), NOW()),
(3, 'https://res.cloudinary.com/dudtaz1xg/image/upload/v1715155200/vehicle-booking/cars/cx5.jpg', 'seed_cx5', 'jpg', 1, NOW(), NOW()),
(4, 'https://res.cloudinary.com/dudtaz1xg/image/upload/v1715155200/vehicle-booking/cars/ranger.jpg', 'seed_ranger', 'jpg', 1, NOW(), NOW()),
(5, 'https://res.cloudinary.com/dudtaz1xg/image/upload/v1715155200/vehicle-booking/cars/xpander.jpg', 'seed_xpander', 'jpg', 1, NOW(), NOW());
