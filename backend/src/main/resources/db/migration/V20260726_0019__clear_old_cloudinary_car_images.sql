-- Xóa ảnh gắn cloud Cloudinary cũ (dudtaz1xg đã disabled).
-- Ảnh Unsplash / cloud mới (lyapg65i) giữ nguyên.
-- Admin upload lại qua app → URL mới trỏ cloud lyapg65i.

DELETE FROM `car_image`
WHERE `image_url` LIKE '%res.cloudinary.com/dudtaz1xg/%'
   OR `image_url` LIKE '%cloudinary.com/dudtaz1xg/%';
