-- ============================================================
-- Clean reseed storefront: 3 chi nhánh, xe không trùng brand+name,
-- địa chỉ xe = địa chỉ chi nhánh, xóa demo booking/invoice cũ.
-- ============================================================

-- 1) Clear transactional + catalog (FK-safe)
DELETE FROM vehicle_tracking_location;
DELETE FROM payment;
DELETE FROM invoice;
DELETE FROM reviews;
DELETE FROM notification;
DELETE FROM booking;
DELETE FROM car_image;
DELETE FROM car;

-- 2) Canonical 3 branches only
UPDATE `branch`
SET `is_active` = b'0'
WHERE `name` NOT IN (
  'GoRento Hoàn Kiếm',
  'GoRento Cầu Giấy',
  'GoRento Thanh Xuân'
);

UPDATE `branch`
SET
  `address` = 'Số 1 Tràng Tiền, Hoàn Kiếm, Hà Nội',
  `phone` = '0901111222',
  `latitude` = 21.0285000,
  `longitude` = 105.8542000,
  `is_active` = b'1'
WHERE `name` = 'GoRento Hoàn Kiếm';

UPDATE `branch`
SET
  `address` = 'Số 15 Duy Tân, Cầu Giấy, Hà Nội',
  `phone` = '0901111333',
  `latitude` = 21.0340000,
  `longitude` = 105.7980000,
  `is_active` = b'1'
WHERE `name` = 'GoRento Cầu Giấy';

UPDATE `branch`
SET
  `address` = 'Số 201 Nguyễn Trãi, Thanh Xuân, Hà Nội',
  `phone` = '0901111444',
  `latitude` = 20.9985000,
  `longitude` = 105.8194000,
  `is_active` = b'1'
WHERE `name` = 'GoRento Thanh Xuân';

INSERT INTO `branch` (`name`, `address`, `phone`, `latitude`, `longitude`, `is_active`)
SELECT 'GoRento Hoàn Kiếm', 'Số 1 Tràng Tiền, Hoàn Kiếm, Hà Nội', '0901111222', 21.0285000, 105.8542000, b'1'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `branch` WHERE `name` = 'GoRento Hoàn Kiếm');

INSERT INTO `branch` (`name`, `address`, `phone`, `latitude`, `longitude`, `is_active`)
SELECT 'GoRento Cầu Giấy', 'Số 15 Duy Tân, Cầu Giấy, Hà Nội', '0901111333', 21.0340000, 105.7980000, b'1'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `branch` WHERE `name` = 'GoRento Cầu Giấy');

INSERT INTO `branch` (`name`, `address`, `phone`, `latitude`, `longitude`, `is_active`)
SELECT 'GoRento Thanh Xuân', 'Số 201 Nguyễn Trãi, Thanh Xuân, Hà Nội', '0901111444', 20.9985000, 105.8194000, b'1'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `branch` WHERE `name` = 'GoRento Thanh Xuân');

-- Resolve branch ids once (stable by name)
SET @b1 := (SELECT `branch_id` FROM `branch` WHERE `name` = 'GoRento Hoàn Kiếm' AND `is_active` = b'1' LIMIT 1);
SET @b2 := (SELECT `branch_id` FROM `branch` WHERE `name` = 'GoRento Cầu Giấy' AND `is_active` = b'1' LIMIT 1);
SET @b3 := (SELECT `branch_id` FROM `branch` WHERE `name` = 'GoRento Thanh Xuân' AND `is_active` = b'1' LIMIT 1);

SET @a1 := (SELECT `address` FROM `branch` WHERE `branch_id` = @b1);
SET @a2 := (SELECT `address` FROM `branch` WHERE `branch_id` = @b2);
SET @a3 := (SELECT `address` FROM `branch` WHERE `branch_id` = @b3);
SET @lat1 := (SELECT `latitude` FROM `branch` WHERE `branch_id` = @b1);
SET @lng1 := (SELECT `longitude` FROM `branch` WHERE `branch_id` = @b1);
SET @lat2 := (SELECT `latitude` FROM `branch` WHERE `branch_id` = @b2);
SET @lng2 := (SELECT `longitude` FROM `branch` WHERE `branch_id` = @b2);
SET @lat3 := (SELECT `latitude` FROM `branch` WHERE `branch_id` = @b3);
SET @lng3 := (SELECT `longitude` FROM `branch` WHERE `branch_id` = @b3);

-- 3) Reseed cars — name KHÔNG chứa brand (tránh "Mercedes-Benz Mercedes-Benz C200")
INSERT INTO car (
    name, brand, model, license_plate, price_per_day, status,
    seats, transmission, fuel_type, location, latitude, longitude,
    location_source, branch_id, created_at, updated_at
) VALUES
-- Branch 1: Hoàn Kiếm
('VF8 Plus',         'VinFast',       'VF8',             '30K-123.45', 1200000, 'AVAILABLE', 5, 'AUTOMATIC', 'ELECTRIC', @a1, @lat1, @lng1, 'BRANCH', @b1, NOW(), NOW()),
('Camry 2.5Q',       'Toyota',        'Camry',           '30E-888.99', 1500000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a1, @lat1, @lng1, 'BRANCH', @b1, NOW(), NOW()),
('C200',             'Mercedes-Benz', 'C200',            '30E-777.11', 3500000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a1, @lat1, @lng1, 'BRANCH', @b1, NOW(), NOW()),
('Q5 2.0 TFSI',      'Audi',          'Q5',              '30F-999.11', 4000000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a1, @lat1, @lng1, 'BRANCH', @b1, NOW(), NOW()),
('CR-V G',           'Honda',         'CR-V',            '30C-222.44', 1100000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a1, @lat1, @lng1, 'BRANCH', @b1, NOW(), NOW()),
('CX-5 Premium',     'Mazda',         'CX-5',            '43A-555.55', 1000000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a1, @lat1, @lng1, 'BRANCH', @b1, NOW(), NOW()),
-- Branch 2: Cầu Giấy
('K3 Premium',       'KIA',           'K3',              '30H-456.78', 750000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a2, @lat2, @lng2, 'BRANCH', @b2, NOW(), NOW()),
('Elantra Sport',    'Hyundai',       'Elantra',         '29A-234.56', 850000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a2, @lat2, @lng2, 'BRANCH', @b2, NOW(), NOW()),
('VF9 Plus',         'VinFast',       'VF9',             '30K-999.88', 2000000, 'AVAILABLE', 7, 'AUTOMATIC', 'ELECTRIC', @a2, @lat2, @lng2, 'BRANCH', @b2, NOW(), NOW()),
('VF6',              'VinFast',       'VF6',             '30K-111.22', 800000,  'AVAILABLE', 5, 'AUTOMATIC', 'ELECTRIC', @a2, @lat2, @lng2, 'BRANCH', @b2, NOW(), NOW()),
('320i',             'BMW',           '320i',            '30F-777.66', 3200000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a2, @lat2, @lng2, 'BRANCH', @b2, NOW(), NOW()),
('Ertiga Hybrid',    'Suzuki',        'Ertiga',          '30B-654.32', 700000,  'AVAILABLE', 7, 'AUTOMATIC', 'HYBRID',   @a2, @lat2, @lng2, 'BRANCH', @b2, NOW(), NOW()),
-- Branch 3: Thanh Xuân
('Ranger Wildtrak',  'Ford',          'Ranger Wildtrak', '29D-456.78', 1400000, 'AVAILABLE', 5, 'AUTOMATIC', 'DIESEL',   @a3, @lat3, @lng3, 'BRANCH', @b3, NOW(), NOW()),
('Xpander Cross',    'Mitsubishi',    'Xpander',         '60A-777.77', 800000,  'AVAILABLE', 7, 'AUTOMATIC', 'GASOLINE', @a3, @lat3, @lng3, 'BRANCH', @b3, NOW(), NOW()),
('Fortuner Legender','Toyota',        'Fortuner',        '30G-555.44', 1800000, 'AVAILABLE', 7, 'AUTOMATIC', 'DIESEL',   @a3, @lat3, @lng3, 'BRANCH', @b3, NOW(), NOW()),
('Santa Fe Premium', 'Hyundai',       'Santa Fe',        '30H-333.22', 1600000, 'AVAILABLE', 7, 'AUTOMATIC', 'GASOLINE', @a3, @lat3, @lng3, 'BRANCH', @b3, NOW(), NOW()),
('Sorento 2.2D',     'KIA',           'Sorento',         '29C-111.33', 1500000, 'AVAILABLE', 7, 'AUTOMATIC', 'DIESEL',   @a3, @lat3, @lng3, 'BRANCH', @b3, NOW(), NOW()),
('Mazda2 Sport',     'Mazda',         'Mazda2',          '29E-789.12', 600000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', @a3, @lat3, @lng3, 'BRANCH', @b3, NOW(), NOW());

-- 4) Primary images by license plate
INSERT INTO car_image (car_id, image_url, public_id, format, bytes, is_primary, sort_order, created_at, updated_at)
SELECT c.car_id,
    CASE c.license_plate
        WHEN '30K-123.45' THEN 'https://images.unsplash.com/photo-1617469767053-d3b523a0b982?w=800'
        WHEN '30E-888.99' THEN 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800'
        WHEN '30E-777.11' THEN 'https://images.unsplash.com/photo-1617814076367-b759aad2c0e0?w=800'
        WHEN '30F-999.11' THEN 'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?w=800'
        WHEN '30C-222.44' THEN 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800'
        WHEN '43A-555.55' THEN 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=800'
        WHEN '30H-456.78' THEN 'https://images.unsplash.com/photo-1619976215249-a9dfe3d09240?w=800'
        WHEN '29A-234.56' THEN 'https://images.unsplash.com/photo-1517994112540-009c47ea476b?w=800'
        WHEN '30K-999.88' THEN 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?w=800'
        WHEN '30K-111.22' THEN 'https://images.unsplash.com/photo-1617104678098-de229db51175?w=800'
        WHEN '30F-777.66' THEN 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=800'
        WHEN '30B-654.32' THEN 'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?w=800'
        WHEN '29D-456.78' THEN 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800'
        WHEN '60A-777.77' THEN 'https://images.unsplash.com/photo-1533106418989-88406c7cc8ca?w=800'
        WHEN '30G-555.44' THEN 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=800'
        WHEN '30H-333.22' THEN 'https://images.unsplash.com/photo-1616422285623-13ff0162193c?w=800'
        WHEN '29C-111.33' THEN 'https://images.unsplash.com/photo-1609521263047-f8f205293f24?w=800'
        WHEN '29E-789.12' THEN 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=800'
    END AS image_url,
    CONCAT('seed/car-', c.car_id) AS public_id,
    'jpg' AS format,
    102400 AS bytes,
    b'1' AS is_primary,
    0 AS sort_order,
    NOW() AS created_at,
    NOW() AS updated_at
FROM car c
WHERE c.license_plate IN (
    '30K-123.45','30E-888.99','30E-777.11','30F-999.11','30C-222.44','43A-555.55',
    '30H-456.78','29A-234.56','30K-999.88','30K-111.22','30F-777.66','30B-654.32',
    '29D-456.78','60A-777.77','30G-555.44','30H-333.22','29C-111.33','29E-789.12'
);

-- 5) Ensure demo accounts exist (password hash = Password123! from initial seed)
INSERT INTO users (name, email, password, phone, role)
SELECT 'GoRento Admin', 'admin@gorento.vn',
       '$2a$10$moAvhjGMF/bmSSW486th8OA0sRQUse0jUGHX5ReeaktPOkkyZus1a',
       '+84987654321', 'ADMIN'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM users WHERE phone = '+84987654321');

INSERT INTO users (name, email, password, phone, role)
SELECT 'GoRento User', 'user@gorento.vn',
       '$2a$10$moAvhjGMF/bmSSW486th8OA0sRQUse0jUGHX5ReeaktPOkkyZus1a',
       '+84123456789', 'USER'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM users WHERE phone = '+84123456789');

-- Normalize roles (no OWNER)
UPDATE users SET role = 'ADMIN' WHERE role = 'OWNER';
