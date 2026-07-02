CREATE TABLE IF NOT EXISTS `users` (
  `user_id` BIGINT NOT NULL AUTO_INCREMENT,
  `driver_license` VARCHAR(255) DEFAULT NULL,
  `email` VARCHAR(255) DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `password` VARCHAR(255) DEFAULT NULL,
  `phone` VARCHAR(255) DEFAULT NULL,
  `role` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `car` (
  `car_id` BIGINT NOT NULL AUTO_INCREMENT,
  `brand` VARCHAR(255) DEFAULT NULL,
  `created_at` DATETIME(6) DEFAULT NULL,
  `fuel_type` ENUM('GASOLINE','DIESEL','ELECTRIC','HYBRID') NOT NULL DEFAULT 'GASOLINE',
  `image_url` VARCHAR(255) DEFAULT NULL,
  `license_plate` VARCHAR(255) DEFAULT NULL,
  `location` VARCHAR(255) DEFAULT NULL,
  `model` VARCHAR(255) DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `price_per_day` DECIMAL(12,2) DEFAULT NULL,
  `seats` INT DEFAULT NULL,
  `status` ENUM('AVAILABLE','PENDING','BOOKED','MAINTENANCE','DISABLED') DEFAULT NULL,
  `transmission` ENUM('AUTOMATIC','MANUAL') NOT NULL DEFAULT 'AUTOMATIC',
  `updated_at` DATETIME(6) DEFAULT NULL,
  PRIMARY KEY (`car_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `booking` (
  `booking_id` BIGINT NOT NULL AUTO_INCREMENT,
  `created_at` DATETIME(6) NOT NULL,
  `end_date` DATE NOT NULL,
  `start_date` DATE NOT NULL,
  `status` ENUM('PENDING','CANCELLED','COMPLETED') NOT NULL,
  `total_price` DECIMAL(12,2) NOT NULL,
  `updated_at` DATETIME(6) NOT NULL,
  `car_id` BIGINT NOT NULL,
  `user_id` BIGINT NOT NULL,
  PRIMARY KEY (`booking_id`),
  KEY `FKd9p8qdy5sj4ym0bmksdx7yrwj` (`car_id`),
  KEY `FK7udbel7q86k041591kj6lfmvw` (`user_id`),
  CONSTRAINT `FK7udbel7q86k041591kj6lfmvw` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `FKd9p8qdy5sj4ym0bmksdx7yrwj` FOREIGN KEY (`car_id`) REFERENCES `car` (`car_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `invoice` (
  `invoice_id` BIGINT NOT NULL AUTO_INCREMENT,
  `created_at` DATETIME(6) NOT NULL,
  `invoice_number` VARCHAR(255) NOT NULL,
  `payment_method` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('FAILED','PAID','UNPAID') NOT NULL,
  `total_amount` DECIMAL(12,2) NOT NULL,
  `updated_at` DATETIME(6) NOT NULL,
  `booking_id` BIGINT NOT NULL,
  PRIMARY KEY (`invoice_id`),
  UNIQUE KEY `UKt6xkdjx1qtd5whp2iljdfn2yj` (`invoice_number`),
  UNIQUE KEY `UK32ywtxrkeu1wnmivu6mlcqdid` (`booking_id`),
  CONSTRAINT `FK4jd6uuk7w0d72riyre2w14fl7` FOREIGN KEY (`booking_id`) REFERENCES `booking` (`booking_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `payment` (
  `payment_id` BIGINT NOT NULL AUTO_INCREMENT,
  `amount` DECIMAL(12,2) NOT NULL,
  `create_at` DATETIME(6) NOT NULL,
  `payment_method` ENUM('BANK_TRANSFER','CASH','MOMO','VNPAY','ZALOPAY') NOT NULL,
  `payment_status` ENUM('FAILED','PENDING','SUCCESS') NOT NULL,
  `transaction_code` VARCHAR(255) DEFAULT NULL,
  `update_at` DATETIME(6) NOT NULL,
  `invoice_id` BIGINT NOT NULL,
  PRIMARY KEY (`payment_id`),
  UNIQUE KEY `UK4l6ndm1m1iw9knbdtxd6m6fyc` (`invoice_id`),
  CONSTRAINT `FKsb24p8f52refbb80qwp4gem9n` FOREIGN KEY (`invoice_id`) REFERENCES `invoice` (`invoice_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `refresh_token` (
  `refresh_token_id` BIGINT NOT NULL AUTO_INCREMENT,
  `created_at` DATETIME(6) NOT NULL,
  `expires_at` DATETIME(6) NOT NULL,
  `token` VARCHAR(255) NOT NULL,
  `user_id` BIGINT NOT NULL,
  PRIMARY KEY (`refresh_token_id`),
  UNIQUE KEY `UKr4k4edos30bx9neoq81mdvwph` (`token`),
  UNIQUE KEY `UKf95ixxe7pa48ryn1awmh2evt7` (`user_id`),
  CONSTRAINT `FKjtx87i0jvq2svedphegvdwcuy` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `password_reset_token` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `created_at` DATETIME(6) NOT NULL,
  `expires_at` DATETIME(6) NOT NULL,
  `otp` VARCHAR(6) NOT NULL,
  `used` BIT(1) NOT NULL,
  `user_id` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK83nsrttkwkb6ym0anu051mtxn` (`user_id`),
  CONSTRAINT `FK83nsrttkwkb6ym0anu051mtxn` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

