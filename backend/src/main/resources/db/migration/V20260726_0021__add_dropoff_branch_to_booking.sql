-- Lưu chi nhánh khách chọn để trả xe. Khi khách trả xe, vị trí xe sẽ chuyển về chi nhánh này.
-- Idempotent: an toàn khi cột/FK đã tồn tại sau lần migrate fail trước đó.

SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'booking'
      AND COLUMN_NAME = 'dropoff_branch_id'
);

SET @sql := IF(
    @col_exists = 0,
    'ALTER TABLE `booking` ADD COLUMN `dropoff_branch_id` BIGINT NULL AFTER `dropoff_longitude`',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'booking'
      AND CONSTRAINT_NAME = 'fk_booking_dropoff_branch'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);

SET @fk_on_col := (
    SELECT COUNT(*)
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'booking'
      AND COLUMN_NAME = 'dropoff_branch_id'
      AND REFERENCED_TABLE_NAME IS NOT NULL
);

SET @sql := IF(
    @fk_exists = 0 AND @fk_on_col = 0,
    'ALTER TABLE `booking` ADD CONSTRAINT `fk_booking_dropoff_branch` FOREIGN KEY (`dropoff_branch_id`) REFERENCES `branch` (`branch_id`)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
