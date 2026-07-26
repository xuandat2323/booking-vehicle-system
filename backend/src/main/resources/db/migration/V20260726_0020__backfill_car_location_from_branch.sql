-- Xe đã gán chi nhánh nhưng chưa có toạ độ thì lấy toạ độ + địa chỉ của chi nhánh,
-- để màn đặt xe điền sẵn điểm giao/nhận thay vì bắt khách chọn lại.

UPDATE `car` c
JOIN `branch` b ON b.`branch_id` = c.`branch_id`
SET c.`latitude` = b.`latitude`,
    c.`longitude` = b.`longitude`,
    c.`location_source` = 'BRANCH',
    c.`location_updated_at` = NOW(),
    c.`location` = COALESCE(NULLIF(TRIM(c.`location`), ''), b.`address`)
WHERE b.`latitude` IS NOT NULL
  AND b.`longitude` IS NOT NULL
  AND (c.`latitude` IS NULL OR c.`longitude` IS NULL);
