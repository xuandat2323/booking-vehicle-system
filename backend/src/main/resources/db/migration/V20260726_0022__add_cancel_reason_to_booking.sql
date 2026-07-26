-- Lưu lý do hủy và hướng xử lý khi admin hủy đơn thuê.
ALTER TABLE `booking`
    ADD COLUMN `cancel_reason` VARCHAR(500) NULL AFTER `status`,
    ADD COLUMN `cancel_handling` VARCHAR(500) NULL AFTER `cancel_reason`;
