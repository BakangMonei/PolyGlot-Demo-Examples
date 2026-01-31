-- Script to drop foreign keys from transactions table before partitioning
-- Run this if you get error: "Foreign keys are not yet supported in conjunction with partitioning"

-- Check existing foreign keys
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'banking'
  AND TABLE_NAME = 'transactions'
  AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Drop foreign keys (MySQL auto-generates names like transactions_ibfk_1, transactions_ibfk_2, etc.)
-- Uncomment and run the appropriate DROP statements based on the query above

-- Option 1: Drop all foreign keys at once (if you know the constraint names)
-- ALTER TABLE transactions 
--   DROP FOREIGN KEY transactions_ibfk_1,
--   DROP FOREIGN KEY transactions_ibfk_2,
--   DROP FOREIGN KEY transactions_ibfk_3;

-- Option 2: Drop them one by one (safer, use if Option 1 fails)
-- ALTER TABLE transactions DROP FOREIGN KEY transactions_ibfk_1;
-- ALTER TABLE transactions DROP FOREIGN KEY transactions_ibfk_2;
-- ALTER TABLE transactions DROP FOREIGN KEY transactions_ibfk_3;

-- Option 3: Dynamic SQL to drop all foreign keys automatically
SET @drop_foreign_keys = (
    SELECT GROUP_CONCAT(
        CONCAT('DROP FOREIGN KEY ', CONSTRAINT_NAME)
        SEPARATOR ', '
    )
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = 'banking'
      AND TABLE_NAME = 'transactions'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);

SET @sql = IF(@drop_foreign_keys IS NOT NULL,
    CONCAT('ALTER TABLE transactions ', @drop_foreign_keys),
    'SELECT "No foreign keys found" AS message'
);

-- Execute the drop statement
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Verify foreign keys are dropped
SELECT 
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'banking'
  AND TABLE_NAME = 'transactions'
  AND CONSTRAINT_TYPE = 'FOREIGN KEY';
-- Should return 0 rows if successful
