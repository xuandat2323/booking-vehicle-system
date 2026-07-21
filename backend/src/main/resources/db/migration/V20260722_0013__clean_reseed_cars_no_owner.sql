-- ============================================================
-- MIGRATION: Clean reseed of car catalog
-- Root cause fixed: migration 010 tried to UPDATE car_id=6/7 with
-- owner_id/coordinates BEFORE those rows existed (they were only
-- created later in the same file by auto-increment), so the update
-- silently affected 0 rows, and the two matching car_image INSERTs
-- were left commented out entirely. Net effect: some cars ended up
-- with no branch, no image, and a stray "owner" account/channel.
--
-- This migration wipes the previous car/image/booking demo data and
-- reseeds cleanly: every car gets a valid branch_id, a primary image,
-- complete created_at/updated_at, and NO owner_id (the peer-to-peer
-- "cho thuê xe" channel is being removed from the product entirely).
-- ============================================================

-- 1. Clear dependent data (FK-safe order)
DELETE FROM vehicle_tracking_location;
DELETE FROM payment;
DELETE FROM invoice;
DELETE FROM reviews;
DELETE FROM booking;
DELETE FROM car_image;
DELETE FROM car;

-- 2. Remove the demo "owner" account — no owner/rental channel in the new data.
--    refresh_token / password_reset_token have plain FKs to users (no ON DELETE
--    CASCADE), so clear those first or the DELETE below fails if the demo owner
--    ever logged in. user_verifications already cascades, no action needed there.
DELETE FROM refresh_token WHERE user_id = (SELECT user_id FROM users WHERE email = 'owner@autorent.com');
DELETE FROM password_reset_token WHERE user_id = (SELECT user_id FROM users WHERE email = 'owner@autorent.com');
DELETE FROM users WHERE email = 'owner@autorent.com';

-- 3. Reseed cars — every row has branch_id set, owner_id left NULL,
--    and created_at/updated_at populated (previously NULL for seed cars).
INSERT INTO car (
    name, brand, model, license_plate, price_per_day, status,
    seats, transmission, fuel_type, location, latitude, longitude,
    location_source, branch_id, created_at, updated_at
) VALUES
-- Branch 1: GoRento Hoàn Kiếm
('VinFast VF8 Plus',         'VinFast',       'VF8',             '30K-123.45', 1200000, 'AVAILABLE', 5, 'AUTOMATIC', 'ELECTRIC', 'Hoàn Kiếm, Hà Nội',    21.0285, 105.8542, 'manual', 1, NOW(), NOW()),
('Toyota Camry 2.5Q',        'Toyota',        'Camry',           '30E-888.99', 1500000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Hoàn Kiếm, Hà Nội',    21.0310, 105.8520, 'manual', 1, NOW(), NOW()),
('Mercedes-Benz C200',       'Mercedes-Benz', 'C200',            '30E-777.11', 3500000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Hoàn Kiếm, Hà Nội',    21.0295, 105.8530, 'manual', 1, NOW(), NOW()),
('Audi Q5 2.0 TFSI',         'Audi',          'Q5',              '30F-999.11', 4000000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Hai Bà Trưng, Hà Nội', 21.0230, 105.8490, 'manual', 1, NOW(), NOW()),
('Honda CR-V G',             'Honda',         'CR-V',            '30C-222.44', 1100000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Ba Đình, Hà Nội',      21.0390, 105.8290, 'manual', 1, NOW(), NOW()),
('Mazda CX-5 Premium',       'Mazda',         'CX-5',            '43A-555.55', 1000000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Đống Đa, Hà Nội',      21.0130, 105.8460, 'manual', 1, NOW(), NOW()),
-- Branch 2: GoRento Cầu Giấy
('KIA K3 Premium',           'KIA',           'K3',              '30H-456.78', 750000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Cầu Giấy, Hà Nội',     21.0340, 105.7980, 'manual', 2, NOW(), NOW()),
('Hyundai Elantra Sport',    'Hyundai',       'Elantra',         '29A-234.56', 850000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Nam Từ Liêm, Hà Nội',  21.0180, 105.7650, 'manual', 2, NOW(), NOW()),
('VinFast VF9 Plus',         'VinFast',       'VF9',             '30K-999.88', 2000000, 'AVAILABLE', 7, 'AUTOMATIC', 'ELECTRIC', 'Mỹ Đình, Hà Nội',      21.0278, 105.7720, 'manual', 2, NOW(), NOW()),
('VinFast VF6',              'VinFast',       'VF6',             '30K-111.22', 800000,  'AVAILABLE', 5, 'AUTOMATIC', 'ELECTRIC', 'Bắc Từ Liêm, Hà Nội',  21.0690, 105.7880, 'manual', 2, NOW(), NOW()),
('BMW 320i',                 'BMW',           '320i',            '30F-777.66', 3200000, 'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Cầu Giấy, Hà Nội',     21.0355, 105.7940, 'manual', 2, NOW(), NOW()),
('Suzuki Ertiga Hybrid',     'Suzuki',        'Ertiga',          '30B-654.32', 700000,  'AVAILABLE', 7, 'AUTOMATIC', 'HYBRID',   'Từ Liêm, Hà Nội',      21.0430, 105.7600, 'manual', 2, NOW(), NOW()),
-- Branch 3: GoRento Thanh Xuân
('Ford Ranger Wildtrak',     'Ford',          'Ranger Wildtrak', '29D-456.78', 1400000, 'AVAILABLE', 5, 'AUTOMATIC', 'DIESEL',   'Thanh Xuân, Hà Nội',   20.9985, 105.8194, 'manual', 3, NOW(), NOW()),
('Mitsubishi Xpander Cross', 'Mitsubishi',    'Xpander',         '60A-777.77', 800000,  'AVAILABLE', 7, 'AUTOMATIC', 'GASOLINE', 'Hà Đông, Hà Nội',      20.9620, 105.7790, 'manual', 3, NOW(), NOW()),
('Toyota Fortuner Legender', 'Toyota',        'Fortuner',        '30G-555.44', 1800000, 'AVAILABLE', 7, 'AUTOMATIC', 'DIESEL',   'Thanh Trì, Hà Nội',    20.9500, 105.8400, 'manual', 3, NOW(), NOW()),
('Hyundai Santa Fe Premium', 'Hyundai',       'Santa Fe',        '30H-333.22', 1600000, 'AVAILABLE', 7, 'AUTOMATIC', 'GASOLINE', 'Thanh Xuân, Hà Nội',   21.0000, 105.8210, 'manual', 3, NOW(), NOW()),
('KIA Sorento 2.2D',         'KIA',           'Sorento',         '29C-111.33', 1500000, 'AVAILABLE', 7, 'AUTOMATIC', 'DIESEL',   'Hoàng Mai, Hà Nội',    20.9850, 105.8720, 'manual', 3, NOW(), NOW()),
('Mazda2 Sport',             'Mazda',         'Mazda2',          '29E-789.12', 600000,  'AVAILABLE', 5, 'AUTOMATIC', 'GASOLINE', 'Thanh Xuân, Hà Nội',   20.9970, 105.8180, 'manual', 3, NOW(), NOW());

-- 4. Primary image for EVERY car (matched by license_plate — robust to
--    whatever car_id auto-increment assigns after the DELETE above)
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
