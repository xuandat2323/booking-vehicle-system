-- Hai ảnh seed cũ trả 404 (Mercedes C200, KIA K3 Premium) nên thẻ xe không lên ảnh.
-- Thay bằng URL Unsplash còn sống.

UPDATE `car_image` ci
INNER JOIN `car` c ON c.`car_id` = ci.`car_id`
SET ci.`image_url` = 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=800',
    ci.`updated_at` = NOW()
WHERE c.`license_plate` = '30E-777.11';

UPDATE `car_image` ci
INNER JOIN `car` c ON c.`car_id` = ci.`car_id`
SET ci.`image_url` = 'https://images.unsplash.com/photo-1590362891991-f776e747a588?w=800',
    ci.`updated_at` = NOW()
WHERE c.`license_plate` = '30H-456.78';
