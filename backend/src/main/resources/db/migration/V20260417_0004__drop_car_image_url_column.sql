SET @has_image_url := (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'car'
      AND column_name = 'image_url'
);

SET @drop_sql := IF(
    @has_image_url > 0,
    'ALTER TABLE `car` DROP COLUMN `image_url`',
    'SELECT 1'
);

PREPARE stmt FROM @drop_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
