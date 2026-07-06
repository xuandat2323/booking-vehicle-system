-- ============================================================
-- MIGRATION: Add Branch (cơ sở), refactor car ownership, update roles
-- ============================================================

-- 1. Create branch table
CREATE TABLE IF NOT EXISTS `branch` (
  `branch_id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `address` VARCHAR(500) NOT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `latitude` DECIMAL(10,7) DEFAULT NULL,
  `longitude` DECIMAL(10,7) DEFAULT NULL,
  `is_active` BIT(1) NOT NULL DEFAULT b'1',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`branch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2. Add branch_id FK to car table
ALTER TABLE `car` ADD COLUMN `branch_id` BIGINT DEFAULT NULL;
ALTER TABLE `car` ADD CONSTRAINT `FK_car_branch` FOREIGN KEY (`branch_id`) REFERENCES `branch` (`branch_id`);

-- 3. Update booking status enum to include new states
ALTER TABLE `booking` MODIFY COLUMN `status`
  ENUM('PENDING','DEPOSIT_PAID','CONFIRMED','RENTING','RETURNED','COMPLETED','CANCELLED') NOT NULL;

-- 4. Add deposit_amount to booking
ALTER TABLE `booking` ADD COLUMN `deposit_amount` DECIMAL(12,2) DEFAULT NULL;

-- 5. Update OWNER role → ADMIN (chỉ giữ 2 role: ADMIN, USER)
UPDATE `users` SET `role` = 'ADMIN' WHERE `role` = 'OWNER';

-- 6. Seed sample branches (cơ sở)
INSERT INTO `branch` (`name`, `address`, `phone`, `latitude`, `longitude`, `is_active`) VALUES
('GoRento Hoàn Kiếm',    'Số 1 Tràng Tiền, Hoàn Kiếm, Hà Nội',         '0901111222', 21.0285000, 105.8542000, b'1'),
('GoRento Cầu Giấy',     'Số 15 Duy Tân, Cầu Giấy, Hà Nội',            '0901111333', 21.0340000, 105.7980000, b'1'),
('GoRento Thanh Xuân',    'Số 201 Nguyễn Trãi, Thanh Xuân, Hà Nội',      '0901111444', 20.9985000, 105.8194000, b'1');

-- 7. Assign existing cars to branches based on location
UPDATE `car` SET `branch_id` = 1 WHERE `location` LIKE '%Hoàn Kiếm%';
UPDATE `car` SET `branch_id` = 2 WHERE `location` LIKE '%Cầu Giấy%' OR `location` LIKE '%Từ Liêm%' OR `location` LIKE '%Mỹ Đình%';
UPDATE `car` SET `branch_id` = 3 WHERE `location` LIKE '%Thanh Xuân%' OR `location` LIKE '%Thanh Trì%' OR `location` LIKE '%Hà Đông%';
-- Remaining unassigned cars → branch 1 (Hoàn Kiếm as default)
UPDATE `car` SET `branch_id` = 1 WHERE `branch_id` IS NULL;

-- 8. Drop owner_id FK from car (optional — keep nullable for backward compat)
-- ALTER TABLE `car` DROP FOREIGN KEY IF EXISTS `FK_car_owner`;
-- ALTER TABLE `car` DROP COLUMN `owner_id`;
