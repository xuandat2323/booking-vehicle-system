-- Bảng notification tạo bởi Hibernate ddl-auto; cột type có thể là ENUM cũ
-- thiếu BOOKING_DEPOSIT_PAID / BOOKING_RENTING / ... → insert thông báo làm 500 khi xác nhận cọc.
-- Đổi sang VARCHAR để khớp @Enumerated(EnumType.STRING).

CREATE TABLE IF NOT EXISTS `notification` (
    `notification_id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `message` TEXT NOT NULL,
    `type` VARCHAR(64) NOT NULL,
    `is_read` BIT(1) NOT NULL DEFAULT b'0',
    `reference_id` BIGINT NULL,
    `created_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`notification_id`),
    KEY `idx_notification_user` (`user_id`),
    CONSTRAINT `fk_notification_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
);

-- Idempotent: nếu cột type đang ENUM/VARCHAR khác thì ép về VARCHAR(64)
SET @sql := (
    SELECT IF(
        EXISTS(
            SELECT 1 FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'notification'
              AND COLUMN_NAME = 'type'
        ),
        'ALTER TABLE `notification` MODIFY COLUMN `type` VARCHAR(64) NOT NULL',
        'SELECT 1'
    )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
