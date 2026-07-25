-- Đảm bảo đúng 3 chi nhánh GoRento; sync địa chỉ xe theo chi nhánh

-- Deactivate any extra branches beyond the canonical 3 names
UPDATE `branch`
SET `is_active` = b'0'
WHERE `name` NOT IN (
  'GoRento Hoàn Kiếm',
  'GoRento Cầu Giấy',
  'GoRento Thanh Xuân'
);

-- Upsert / refresh canonical branches (keep existing IDs if present)
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

-- Every car must belong to an active branch; default Hoàn Kiếm
UPDATE `car` c
LEFT JOIN `branch` b ON c.`branch_id` = b.`branch_id` AND b.`is_active` = b'1'
SET c.`branch_id` = (
  SELECT `branch_id` FROM `branch` WHERE `name` = 'GoRento Hoàn Kiếm' AND `is_active` = b'1' LIMIT 1
)
WHERE c.`branch_id` IS NULL OR b.`branch_id` IS NULL;

-- Sync car.location + coords from branch (storefront model)
UPDATE `car` c
INNER JOIN `branch` b ON c.`branch_id` = b.`branch_id`
SET
  c.`location` = b.`address`,
  c.`latitude` = b.`latitude`,
  c.`longitude` = b.`longitude`,
  c.`location_source` = 'BRANCH';
