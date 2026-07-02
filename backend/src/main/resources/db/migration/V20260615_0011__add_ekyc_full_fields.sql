-- Add eKYC full verification fields (idempotent via stored procedure)
DROP PROCEDURE IF EXISTS add_col_if_not_exists;

CREATE PROCEDURE add_col_if_not_exists(IN tbl VARCHAR(64), IN col VARCHAR(64), IN def TEXT)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND COLUMN_NAME = col
    ) THEN
        SET @s = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', def);
        PREPARE stmt FROM @s;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END;

CALL add_col_if_not_exists('user_verifications', 'cccd_back_verified',  'BOOLEAN DEFAULT FALSE');
CALL add_col_if_not_exists('user_verifications', 'cccd_back_spoofed',   'BOOLEAN DEFAULT FALSE');
CALL add_col_if_not_exists('user_verifications', 'cccd_back_number',    'VARCHAR(50)');
CALL add_col_if_not_exists('user_verifications', 'license_back_verified','BOOLEAN DEFAULT FALSE');
CALL add_col_if_not_exists('user_verifications', 'license_back_spoofed', 'BOOLEAN DEFAULT FALSE');
CALL add_col_if_not_exists('user_verifications', 'face_match_verified',  'BOOLEAN DEFAULT FALSE');
CALL add_col_if_not_exists('user_verifications', 'face_match_score',     'FLOAT');
CALL add_col_if_not_exists('user_verifications', 'liveness_verified',    'BOOLEAN DEFAULT FALSE');
CALL add_col_if_not_exists('user_verifications', 'liveness_score',       'FLOAT');

DROP PROCEDURE IF EXISTS add_col_if_not_exists;
