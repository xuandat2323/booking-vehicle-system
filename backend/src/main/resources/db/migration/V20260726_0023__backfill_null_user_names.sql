-- Backfill users with null/blank name so admin notifications don't show "khách null".
UPDATE `users`
SET `name` = CONCAT('Khách ', RIGHT(REPLACE(COALESCE(`phone`, ''), '+', ''), 4))
WHERE `name` IS NULL OR TRIM(`name`) = '';
