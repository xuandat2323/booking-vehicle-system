CREATE TABLE IF NOT EXISTS `car_image` (
  `car_image_id` BIGINT NOT NULL AUTO_INCREMENT,
  `car_id` BIGINT NOT NULL,
  `image_url` VARCHAR(1000) NOT NULL,
  `public_id` VARCHAR(255) NOT NULL,
  `format` VARCHAR(20) NOT NULL,
  `bytes` BIGINT DEFAULT NULL,
  `is_primary` BIT(1) NOT NULL DEFAULT b'0',
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME(6) NOT NULL,
  `updated_at` DATETIME(6) NOT NULL,
  PRIMARY KEY (`car_image_id`),
  CONSTRAINT `fk_car_image_car`
    FOREIGN KEY (`car_id`) REFERENCES `car` (`car_id`),
  CONSTRAINT `uq_car_image_public_id`
    UNIQUE (`public_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
