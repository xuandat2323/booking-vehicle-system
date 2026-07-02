-- ============================================================
-- SEED: Diverse cars with coordinates + demo bookings
-- ============================================================

-- Add owner user for demo
INSERT INTO users (name, email, password, phone, role) VALUES
('Trần Văn Chủ Xe', 'owner@autorent.com', '$2a$10$moAvhjGMF/bmSSW486th8OA0sRQUse0jUGHX5ReeaktPOkkyZus1a', '+84901234567', 'USER');

-- Update existing cars with Hanoi coordinates
UPDATE car SET latitude=21.0285, longitude=105.8542, location='Hoàn Kiếm, Hà Nội',       location_source='manual' WHERE car_id=1;
UPDATE car SET latitude=21.0376, longitude=105.8340, location='Ba Đình, Hà Nội',          location_source='manual' WHERE car_id=2;
UPDATE car SET latitude=21.0120, longitude=105.8437, location='Đống Đa, Hà Nội',          location_source='manual' WHERE car_id=3;
UPDATE car SET latitude=21.0458, longitude=105.8736, location='Long Biên, Hà Nội',        location_source='manual' WHERE car_id=4;
UPDATE car SET latitude=20.9985, longitude=105.8194, location='Thanh Xuân, Hà Nội',       location_source='manual' WHERE car_id=5;
UPDATE car SET latitude=21.0245, longitude=105.8412, location='Hai Bà Trưng, Hà Nội',    location_source='manual',
    owner_id=(SELECT user_id FROM users WHERE phone='+84901234567' LIMIT 1) WHERE car_id=6;
UPDATE car SET latitude=21.0550, longitude=105.8210, location='Tây Hồ, Hà Nội',          location_source='manual',
    owner_id=(SELECT user_id FROM users WHERE phone='+84901234567' LIMIT 1) WHERE car_id=7;

-- Fix existing images: set is_primary=true
UPDATE car_image SET is_primary=b'1' WHERE car_id IN (1,2,3,4,5) AND is_primary=b'0';

-- Images for cars 6 and 7 (previously missing)
-- INSERT INTO car_image (car_id, image_url, public_id, format, bytes, is_primary, sort_order, created_at, updated_at) VALUES
-- (6, 'https://images.unsplash.com/photo-1619976215249-a9dfe3d09240?w=800', 'seed/honda-city-6', 'jpg', 102400, b'1', 0, NOW(), NOW()),
-- (7, 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800', 'seed/honda-city-7', 'jpg', 102400, b'1', 0, NOW(), NOW());

-- New diverse cars (22 cars total after inserts)
INSERT INTO car (name, brand, model, license_plate, price_per_day, status, seats, transmission, fuel_type, location, latitude, longitude, location_source) VALUES
('KIA K3 Premium',           'KIA',          'K3',             '30H-456.78', 750000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Cầu Giấy, Hà Nội',      21.0340, 105.7980, 'manual'),
('Hyundai Elantra Sport',    'Hyundai',      'Elantra',        '29A-234.56', 850000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Nam Từ Liêm, Hà Nội',   21.0180, 105.7650, 'manual'),
('Mercedes-Benz C200',       'Mercedes-Benz','C200',           '30E-888.99', 3500000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Hoàn Kiếm, Hà Nội',     21.0310, 105.8520, 'manual'),
('BMW 320i',                 'BMW',          '320i',           '30F-777.66', 3200000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Ba Đình, Hà Nội',        21.0390, 105.8290, 'manual'),
('Toyota Fortuner Legender', 'Toyota',       'Fortuner',       '30G-555.44', 1800000, 'AVAILABLE', 7, 'AUTOMATIC', 'DIESEL',   'Hoàng Mai, Hà Nội',     20.9850, 105.8720, 'manual'),
('Hyundai Santa Fe Premium', 'Hyundai',      'Santa Fe',       '30H-333.22', 1600000, 'AVAILABLE', 7, 'AUTOMATIC', 'GASOLINE', 'Đông Anh, Hà Nội',      21.1340, 105.8590, 'manual'),
('KIA Sorento 2.2D',         'KIA',          'Sorento',        '29C-111.33', 1500000, 'AVAILABLE', 7, 'AUTOMATIC', 'DIESEL',   'Gia Lâm, Hà Nội',       20.9990, 105.9120, 'manual'),
('VinFast VF9 Plus',         'VinFast',      'VF9',            '30K-999.88', 2000000, 'AVAILABLE', 7, 'AUTOMATIC', 'ELECTRIC', 'Mỹ Đình, Hà Nội',       21.0278, 105.7720, 'manual'),
('VinFast VF6',              'VinFast',      'VF6',            '30K-111.22', 800000,  'AVAILABLE', 5, 'AUTOMATIC', 'ELECTRIC', 'Bắc Từ Liêm, Hà Nội',   21.0690, 105.7880, 'manual'),
('Ford Ranger Wildtrak',     'Ford',         'Ranger Wildtrak','29D-456.78', 1400000, 'AVAILABLE', 5, 'AUTOMATIC', 'DIESEL',   'Sóc Sơn, Hà Nội',       21.2310, 105.8640, 'manual'),
('Toyota Veloz Cross',       'Toyota',       'Veloz Cross',    '30A-123.99', 900000,  'AVAILABLE', 7, 'AUTOMATIC', 'GASOLINE', 'Hà Đông, Hà Nội',       20.9620, 105.7790, 'manual'),
('Suzuki Ertiga Hybrid',     'Suzuki',       'Ertiga',         '30B-654.32', 700000,  'AVAILABLE', 7, 'AUTOMATIC', 'HYBRID',   'Từ Liêm, Hà Nội',       21.0430, 105.7600, 'manual'),
('Mazda2 Sport',             'Mazda',        'Mazda2',         '29E-789.12', 600000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Thanh Trì, Hà Nội',     20.9500, 105.8400, 'manual'),
('Audi Q5 2.0 TFSI',         'Audi',         'Q5',             '30F-999.11', 4000000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Hoàn Kiếm, Hà Nội',     21.0320, 105.8510, 'manual'),
('Honda CR-V G',             'Honda',        'CR-V',           '30C-222.44', 1100000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Hai Bà Trưng, Hà Nội',  21.0230, 105.8490, 'manual'),
('Mitsubishi Outlander 2.0', 'Mitsubishi',   'Outlander',      '30D-333.55', 1200000, 'AVAILABLE', 7, 'AUTOMATIC', 'GASOLINE', 'Đống Đa, Hà Nội',       21.0130, 105.8460, 'manual');

-- Car images for new cars (use Unsplash for reliable public URLs)
INSERT INTO car_image (car_id, image_url, public_id, format, bytes, is_primary, sort_order, created_at, updated_at)
SELECT c.car_id,
    CASE c.license_plate
        WHEN '30H-456.78' THEN 'https://images.unsplash.com/photo-1619976215249-a9dfe3d09240?w=800'
        WHEN '29A-234.56' THEN 'https://images.unsplash.com/photo-1517994112540-009c47ea476b?w=800'
        WHEN '30E-888.99' THEN 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800'
        WHEN '30F-777.66' THEN 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=800'
        WHEN '30G-555.44' THEN 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=800'
        WHEN '30H-333.22' THEN 'https://images.unsplash.com/photo-1616422285623-13ff0162193c?w=800'
        WHEN '29C-111.33' THEN 'https://images.unsplash.com/photo-1609521263047-f8f205293f24?w=800'
        WHEN '30K-999.88' THEN 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?w=800'
        WHEN '30K-111.22' THEN 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?w=800'
        WHEN '29D-456.78' THEN 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800'
        WHEN '30A-123.99' THEN 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=800'
        WHEN '30B-654.32' THEN 'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?w=800'
        WHEN '29E-789.12' THEN 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=800'
        WHEN '30F-999.11' THEN 'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?w=800'
        WHEN '30C-222.44' THEN 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800'
        WHEN '30D-333.55' THEN 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=800'
    END as image_url,
    CONCAT('seed/car-', c.car_id) as public_id,
    'jpg' as format,
    102400 as bytes,
    b'1' as is_primary,
    0 as sort_order,
    NOW() as created_at,
    NOW() as updated_at
FROM car c
WHERE c.license_plate IN (
    '30H-456.78','29A-234.56','30E-888.99','30F-777.66','30G-555.44','30H-333.22',
    '29C-111.33','30K-999.88','30K-111.22','29D-456.78','30A-123.99','30B-654.32',
    '29E-789.12','30F-999.11','30C-222.44','30D-333.55'
);

-- Demo bookings in different statuses
INSERT INTO booking (car_id, user_id, start_date, end_date, status, total_price,
    pickup_address, pickup_latitude, pickup_longitude,
    dropoff_address, dropoff_latitude, dropoff_longitude,
    created_at, updated_at)
VALUES
(3, 2, DATE_ADD(CURDATE(), INTERVAL 5  DAY), DATE_ADD(CURDATE(), INTERVAL 7  DAY), 'PENDING',    2000000,
 'Sân bay Nội Bài, Hà Nội', 21.2187, 105.8047, 'Khách sạn Sofitel, Hoàn Kiếm', 21.0285, 105.8542, NOW(), NOW()),

(2, 2, DATE_ADD(CURDATE(), INTERVAL 10 DAY), DATE_ADD(CURDATE(), INTERVAL 13 DAY), 'CONFIRMED',  4500000,
 'Ga Hà Nội, Hoàn Kiếm', 21.0242, 105.8412, 'AEON Mall Long Biên', 21.0460, 105.8763, NOW(), NOW()),

(1, 2, DATE_SUB(CURDATE(), INTERVAL 10 DAY), DATE_SUB(CURDATE(), INTERVAL 8  DAY), 'COMPLETED',  2400000,
 'Sân bay Nội Bài, Hà Nội', 21.2187, 105.8047, 'Hồ Hoàn Kiếm, Hà Nội', 21.0285, 105.8542,
 DATE_SUB(NOW(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 8 DAY)),

(4, 2, DATE_ADD(CURDATE(), INTERVAL 2  DAY), DATE_ADD(CURDATE(), INTERVAL 4  DAY), 'CANCELLED',  2600000,
 'Bến xe Mỹ Đình', 21.0278, 105.7722, 'Làng Văn hóa các dân tộc', 21.0150, 105.7600,
 DATE_SUB(NOW(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY));

-- Vehicle tracking seed
INSERT INTO vehicle_tracking_location (car_id, latitude, longitude, speed_kmh, heading, address, source, is_current, created_at, updated_at) VALUES
(1, 21.0285, 105.8542, 0, 0, 'Hoàn Kiếm, Hà Nội', 'manual', 1, NOW(), NOW()),
(2, 21.0376, 105.8340, 0, 0, 'Ba Đình, Hà Nội',   'manual', 1, NOW(), NOW()),
(3, 21.0120, 105.8437, 0, 0, 'Đống Đa, Hà Nội',   'manual', 1, NOW(), NOW());
