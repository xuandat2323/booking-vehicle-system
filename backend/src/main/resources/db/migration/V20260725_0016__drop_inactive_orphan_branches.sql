-- Remove inactive duplicate branches left by charset/name mismatches.
-- Safe: only deletes inactive branches that no car references.
DELETE FROM `branch`
WHERE `is_active` = b'0'
  AND `branch_id` NOT IN (
    SELECT t.bid FROM (
      SELECT DISTINCT `branch_id` AS bid FROM `car` WHERE `branch_id` IS NOT NULL
    ) t
  );
