-- MySQL 8.0 Banking Schema
-- System of Record - Financial Transactions

-- Enable required features
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
# SET default_time_zone = '+00:00';

-- Create database
CREATE DATABASE IF NOT EXISTS banking CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE banking;


-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Customers table
CREATE TABLE customers
(
    customer_id   BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    customer_uuid CHAR(36)     NOT NULL UNIQUE,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    phone         VARCHAR(20),
    date_of_birth DATE         NOT NULL,
    ssn_hash      VARCHAR(64)  NOT NULL COMMENT 'SHA-256 hash of SSN',
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city          VARCHAR(100),
    state         VARCHAR(50),
    postal_code   VARCHAR(20),
    country       VARCHAR(2)                                         DEFAULT 'US',
    created_at    TIMESTAMP                                          DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP                                          DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status        ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'CLOSED') DEFAULT 'ACTIVE',
    INDEX idx_email (email),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    FULLTEXT INDEX idx_name (first_name, last_name) WITH PARSER ngram
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='Customer master data';

-- Accounts table
CREATE TABLE accounts
(
    account_id        BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    account_number    VARCHAR(20)                                                  NOT NULL UNIQUE,
    customer_id       BIGINT UNSIGNED                                              NOT NULL,
    account_type      ENUM ('CHECKING', 'SAVINGS', 'CREDIT', 'LOAN', 'INVESTMENT') NOT NULL,
    balance           DECIMAL(20, 2)                                               NOT NULL DEFAULT 0.00,
    available_balance DECIMAL(20, 2)                                               NOT NULL DEFAULT 0.00,
    currency          VARCHAR(3)                                                            DEFAULT 'USD',
    interest_rate     DECIMAL(5, 4)                                                         DEFAULT 0.0000,
    opened_date       DATE                                                         NOT NULL,
    closed_date       DATE                                                         NULL,
    status            ENUM ('ACTIVE', 'FROZEN', 'CLOSED', 'PENDING')                        DEFAULT 'ACTIVE',
    created_at        TIMESTAMP                                                             DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP                                                             DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id) ON DELETE RESTRICT,
    INDEX idx_customer_id (customer_id),
    INDEX idx_account_number (account_number),
    INDEX idx_status (status),
    INDEX idx_opened_date (opened_date)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='Account master data';

-- Transactions table (time-series optimized)
CREATE TABLE transactions
(
    transaction_id         BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    transaction_uuid       CHAR(36)                                                                           NOT NULL UNIQUE,
    account_id             BIGINT UNSIGNED                                                                    NOT NULL,
    customer_id            BIGINT UNSIGNED                                                                    NOT NULL,
    transaction_type       ENUM ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'PAYMENT', 'FEE', 'INTEREST', 'REFUND') NOT NULL,
    amount                 DECIMAL(20, 2)                                                                     NOT NULL,
    balance_after          DECIMAL(20, 2)                                                                     NOT NULL,
    currency               VARCHAR(3)                                                       DEFAULT 'USD',
    description            VARCHAR(500),
    reference_number       VARCHAR(100),
    related_transaction_id BIGINT UNSIGNED                                                                    NULL,
    merchant_id            BIGINT UNSIGNED                                                                    NULL,
    transaction_date       TIMESTAMP                                                                          NOT NULL,
    posted_date            TIMESTAMP                                                                          NULL,
    status                 ENUM ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED', 'REVERSED') DEFAULT 'PENDING',
    fraud_score            DECIMAL(5, 4)                                                                      NULL,
    created_at             TIMESTAMP                                                        DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP                                                        DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- Audit hash for compliance (calculated via trigger)
    audit_hash             VARCHAR(64)                                                                        NULL,
    FOREIGN KEY (account_id) REFERENCES accounts (account_id) ON DELETE RESTRICT,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id) ON DELETE RESTRICT,
    FOREIGN KEY (related_transaction_id) REFERENCES transactions (transaction_id) ON DELETE SET NULL,
    INDEX idx_account_id (account_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_transaction_date (transaction_date),
    INDEX idx_status (status),
    INDEX idx_transaction_type (transaction_type),
    INDEX idx_audit_hash (audit_hash),
    INDEX idx_related_transaction (related_transaction_id),
    -- Composite index for common queries
    INDEX idx_customer_date_type (customer_id, transaction_date DESC, transaction_type)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='Transaction history with audit trail';

-- Partition transactions by year for better performance
-- Note: Foreign keys removed to enable partitioning (MySQL limitation)
-- Referential integrity enforced via triggers: transactions_validate_account,
-- transactions_validate_customer, transactions_validate_related_transaction

-- Drop any existing foreign keys before partitioning (required for partitioning)
-- This handles the case where the table was created with foreign keys
SET @drop_fk_sql = NULL;
SELECT GROUP_CONCAT(
               CONCAT('DROP FOREIGN KEY ', CONSTRAINT_NAME)
               SEPARATOR ', '
       )
INTO @drop_fk_sql
FROM information_schema.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'transactions'
  AND CONSTRAINT_TYPE = 'FOREIGN KEY';

-- Execute drop statement if foreign keys exist
SET @alter_sql = IF(@drop_fk_sql IS NOT NULL,
                    CONCAT('ALTER TABLE transactions ', @drop_fk_sql),
                    'SELECT 1' -- Dummy statement if no foreign keys
                 );

PREPARE stmt FROM @alter_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add computed column for partitioning if table already exists without it
-- (This is safe to run even if column already exists - will be ignored)
SET @col_exists = (SELECT COUNT(*)
                   FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE()
                     AND TABLE_NAME = 'transactions'
                     AND COLUMN_NAME = 'transaction_year');

SET @add_col_sql = IF(@col_exists = 0,
                      'ALTER TABLE transactions ADD COLUMN transaction_year INT AS (YEAR(transaction_date)) STORED AFTER updated_at',
                      'SELECT 1' -- Dummy statement if column already exists
                   );

PREPARE stmt FROM @add_col_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;


-- Modify primary key to include transaction_year if table already exists
-- Check if primary key needs to be updated (if it doesn't include transaction_year)
SET @pk_has_year = (SELECT COUNT(*)
                    FROM information_schema.KEY_COLUMN_USAGE
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'transactions'
                      AND CONSTRAINT_NAME = 'PRIMARY'
                      AND COLUMN_NAME = 'transaction_year');

SET @table_exists = (SELECT COUNT(*)
                     FROM information_schema.TABLES
                     WHERE TABLE_SCHEMA = DATABASE()
                       AND TABLE_NAME = 'transactions');

-- Only modify PK if table exists, column exists, and PK doesn't include transaction_year
SET @modify_pk_sql = IF(@table_exists > 0 AND @col_exists > 0 AND @pk_has_year = 0,
                        'ALTER TABLE transactions DROP PRIMARY KEY, ADD PRIMARY KEY (transaction_year, transaction_id)',
                        'SELECT 1' -- Dummy statement if conditions not met
                     );

PREPARE stmt FROM @modify_pk_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SHOW CREATE TABLE transactions;
DESCRIBE transactions;

ALTER TABLE transactions
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (transaction_id, transaction_year);

ALTER TABLE transactions
    DROP INDEX transaction_uuid,
    ADD UNIQUE KEY uq_transaction_uuid_year (transaction_uuid, transaction_year);

ALTER TABLE transactions
    PARTITION BY RANGE (transaction_year) (
        PARTITION p2020 VALUES LESS THAN (2021),
        PARTITION p2021 VALUES LESS THAN (2022),
        PARTITION p2022 VALUES LESS THAN (2023),
        PARTITION p2023 VALUES LESS THAN (2024),
        PARTITION p2024 VALUES LESS THAN (2025),
        PARTITION p2025 VALUES LESS THAN (2026),
        PARTITION p2026 VALUES LESS THAN (2027),
        PARTITION p2027 VALUES LESS THAN (2028),
        PARTITION p2028 VALUES LESS THAN (2029),
        PARTITION p2029 VALUES LESS THAN (2030),
        PARTITION p_future VALUES LESS THAN MAXVALUE
        );



-- ============================================================================
-- REFERENCE TABLES
-- ============================================================================

-- Branches table (with spatial data)
CREATE TABLE branches
(
    branch_id     INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    branch_code   VARCHAR(10)  NOT NULL UNIQUE,
    branch_name   VARCHAR(100) NOT NULL,
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city          VARCHAR(100),
    state         VARCHAR(50),
    postal_code   VARCHAR(20),
    country       VARCHAR(2)                            DEFAULT 'US',
    phone         VARCHAR(20),
    email         VARCHAR(255),
    location      POINT        NOT NULL COMMENT 'Geographic coordinates',
    timezone      VARCHAR(50)                           DEFAULT 'UTC',
    status        ENUM ('ACTIVE', 'INACTIVE', 'CLOSED') DEFAULT 'ACTIVE',
    created_at    TIMESTAMP                             DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP                             DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    SPATIAL INDEX idx_location (location),
    INDEX idx_branch_code (branch_code),
    INDEX idx_status (status)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='Branch locations with spatial indexing';

-- ATMs table (with spatial data)
CREATE TABLE atms
(
    atm_id        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    atm_code      VARCHAR(10)  NOT NULL UNIQUE,
    branch_id     INT UNSIGNED NULL,
    location_name VARCHAR(100),
    address_line1 VARCHAR(255),
    city          VARCHAR(100),
    state         VARCHAR(50),
    postal_code   VARCHAR(20),
    location      POINT        NOT NULL,
    status        ENUM ('ACTIVE', 'INACTIVE', 'OUT_OF_SERVICE') DEFAULT 'ACTIVE',
    created_at    TIMESTAMP                                     DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (branch_id) REFERENCES branches (branch_id) ON DELETE SET NULL,
    SPATIAL INDEX idx_location (location),
    INDEX idx_atm_code (atm_code),
    INDEX idx_status (status)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='ATM locations';

-- Merchants table
CREATE TABLE merchants
(
    merchant_id       BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    merchant_code     VARCHAR(20)  NOT NULL UNIQUE,
    merchant_name     VARCHAR(255) NOT NULL,
    merchant_category VARCHAR(100),
    location          POINT        NOT NULL,
    status            ENUM ('ACTIVE', 'INACTIVE', 'BLACKLISTED') DEFAULT 'ACTIVE',
    created_at        TIMESTAMP                                  DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP                                  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status),
    SPATIAL INDEX idx_location (location)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='Merchant information';


-- ============================================================================
-- AUDIT AND COMPLIANCE TABLES
-- ============================================================================

-- Customer correspondence table (for full-text search)
CREATE TABLE customer_correspondence
(
    correspondence_id   BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    customer_id         BIGINT UNSIGNED                                        NOT NULL,
    correspondence_type ENUM ('EMAIL', 'LETTER', 'PHONE', 'CHAT', 'IN_PERSON') NOT NULL,
    subject             VARCHAR(500),
    body                TEXT,
    direction           ENUM ('INBOUND', 'OUTBOUND')                           NOT NULL,
    created_by          VARCHAR(100),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id) ON DELETE RESTRICT,
    INDEX idx_customer_id (customer_id),
    INDEX idx_created_at (created_at),
    FULLTEXT INDEX idx_fulltext (subject, body) WITH PARSER ngram
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='Customer correspondence with full-text search';

-- Audit log table
CREATE TABLE audit_log
(
    audit_id   BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(100)                        NOT NULL,
    record_id  BIGINT UNSIGNED                     NOT NULL,
    action     ENUM ('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON                                NULL,
    new_values JSON                                NULL,
    user_id    VARCHAR(100)                        NOT NULL,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='Comprehensive audit trail';

-- ============================================================================
-- ROW-LEVEL SECURITY TABLES
-- ============================================================================

-- User permissions table for RLS
CREATE TABLE user_permissions
(
    user_id      VARCHAR(100) PRIMARY KEY,
    customer_ids JSON        NOT NULL COMMENT 'Array of customer IDs user can access',
    role         VARCHAR(50) NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_role (role)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
    COMMENT ='User permissions for row-level security';

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Customer account summary view
CREATE VIEW customer_account_summary AS
SELECT c.customer_id,
       c.first_name,
       c.last_name,
       c.email,
       COUNT(DISTINCT a.account_id)                         as total_accounts,
       SUM(CASE WHEN a.status = 'ACTIVE' THEN 1 ELSE 0 END) as active_accounts,
       SUM(a.balance)                                       as total_balance,
       SUM(a.available_balance)                             as total_available_balance,
       MAX(a.opened_date)                                   as latest_account_opened
FROM customers c
         LEFT JOIN accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email;

-- Transaction summary view (for analytics)
CREATE VIEW transaction_summary_daily AS
SELECT DATE(transaction_date) as transaction_date,
       customer_id,
       transaction_type,
       COUNT(*)               as transaction_count,
       SUM(amount)            as total_amount,
       AVG(amount)            as avg_amount,
       MIN(amount)            as min_amount,
       MAX(amount)            as max_amount
FROM transactions
WHERE status = 'COMPLETED'
GROUP BY DATE(transaction_date), customer_id, transaction_type;

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

DELIMITER //

-- Procedure to create a new account
CREATE PROCEDURE create_account(
    IN p_customer_id BIGINT UNSIGNED,
    IN p_account_type ENUM ('CHECKING', 'SAVINGS', 'CREDIT', 'LOAN', 'INVESTMENT'),
    IN p_initial_balance DECIMAL(20, 2),
    OUT p_account_id BIGINT UNSIGNED,
    OUT p_account_number VARCHAR(20)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

    START TRANSACTION;

    -- Generate account number
    SET p_account_number = CONCAT('ACC', LPAD(FLOOR(RAND() * 9999999999), 10, '0'));

    -- Create account
    INSERT INTO accounts (account_number,
                          customer_id,
                          account_type,
                          balance,
                          available_balance,
                          opened_date,
                          status)
    VALUES (p_account_number,
            p_customer_id,
            p_account_type,
            p_initial_balance,
            p_initial_balance,
            CURDATE(),
            'ACTIVE');

    SET p_account_id = LAST_INSERT_ID();

    -- Create initial transaction if balance > 0
    IF p_initial_balance > 0 THEN
        INSERT INTO transactions (transaction_uuid,
                                  account_id,
                                  customer_id,
                                  transaction_type,
                                  amount,
                                  balance_after,
                                  transaction_date,
                                  posted_date,
                                  status,
                                  description)
        VALUES (UUID(),
                p_account_id,
                p_customer_id,
                'DEPOSIT',
                p_initial_balance,
                p_initial_balance,
                NOW(),
                NOW(),
                'COMPLETED',
                'Initial account deposit');
    END IF;
    COMMIT;
END;

-- Procedure to process a transfer
CREATE PROCEDURE process_transfer(
    IN p_from_account_id BIGINT UNSIGNED,
    IN p_to_account_id BIGINT UNSIGNED,
    IN p_amount DECIMAL(20, 2),
    IN p_description VARCHAR(500),
    OUT p_transaction_id BIGINT UNSIGNED,
    OUT p_status VARCHAR(20)
)
BEGIN
    DECLARE v_from_customer_id BIGINT UNSIGNED;
    DECLARE v_to_customer_id BIGINT UNSIGNED;
    DECLARE v_from_balance DECIMAL(20, 2);
    DECLARE v_to_balance DECIMAL(20, 2);
    DECLARE v_transaction_uuid CHAR(36);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SET p_status = 'FAILED';
            RESIGNAL;
        END;

    START TRANSACTION;

    -- Get account information
    SELECT customer_id, available_balance
    INTO v_from_customer_id, v_from_balance
    FROM accounts
    WHERE account_id = p_from_account_id
      AND status = 'ACTIVE'
        FOR
    UPDATE;

    SELECT customer_id, balance
    INTO v_to_customer_id, v_to_balance
    FROM accounts
    WHERE account_id = p_to_account_id
      AND status = 'ACTIVE'
        FOR
    UPDATE;

    -- Validate sufficient balance
    IF v_from_balance < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
    END IF;

    SET v_transaction_uuid = UUID();

    -- Debit from account
    UPDATE accounts
    SET balance           = balance - p_amount,
        available_balance = available_balance - p_amount,
        updated_at        = NOW()
    WHERE account_id = p_from_account_id;

    -- Credit to account
    UPDATE accounts
    SET balance           = balance + p_amount,
        available_balance = available_balance + p_amount,
        updated_at        = NOW()
    WHERE account_id = p_to_account_id;

    -- Create debit transaction
    INSERT INTO transactions (transaction_uuid,
                              account_id,
                              customer_id,
                              transaction_type,
                              amount,
                              balance_after,
                              transaction_date,
                              posted_date,
                              status,
                              description,
                              related_transaction_id)
    VALUES (v_transaction_uuid,
            p_from_account_id,
            v_from_customer_id,
            'TRANSFER',
            -p_amount,
            v_from_balance - p_amount,
            NOW(),
            NOW(),
            'COMPLETED',
            CONCAT('Transfer to account ', p_to_account_id, ': ', p_description),
            NULL);

    SET p_transaction_id = LAST_INSERT_ID();

    -- Create credit transaction
    INSERT INTO transactions (transaction_uuid,
                              account_id,
                              customer_id,
                              transaction_type,
                              amount,
                              balance_after,
                              transaction_date,
                              posted_date,
                              status,
                              description,
                              related_transaction_id)
    VALUES (UUID(),
            p_to_account_id,
            v_to_customer_id,
            'TRANSFER',
            p_amount,
            v_to_balance + p_amount,
            NOW(),
            NOW(),
            'COMPLETED',
            CONCAT('Transfer from account ', p_from_account_id, ': ', p_description),
            p_transaction_id);

    -- Update related transaction
    UPDATE transactions
    SET related_transaction_id = LAST_INSERT_ID()
    WHERE transaction_id = p_transaction_id;

    SET p_status = 'COMPLETED';
    COMMIT;
END;

DELIMITER ;

-- ============================================================================
-- TRIGGERS FOR AUDIT LOGGING
-- ============================================================================

DELIMITER //

-- Trigger for account changes
CREATE TRIGGER accounts_audit_update
    AFTER UPDATE
    ON accounts
    FOR EACH ROW
BEGIN
    IF OLD.balance != NEW.balance OR OLD.status != NEW.status THEN
        INSERT INTO audit_log (table_name,
                               record_id,
                               action,
                               old_values,
                               new_values,
                               user_id)
        VALUES ('accounts',
                NEW.account_id,
                'UPDATE',
                JSON_OBJECT(
                        'balance', OLD.balance,
                        'status', OLD.status
                ),
                JSON_OBJECT(
                        'balance', NEW.balance,
                        'status', NEW.status
                ),
                USER());
    END IF;
END;

DELIMITER ;

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- Insert sample branch data
INSERT INTO branches (branch_code, branch_name, address_line1, city, state, postal_code, location)
VALUES ('NYC001', 'New York Main Branch', '123 Wall Street', 'New York', 'NY', '10005',
        ST_GeomFromText('POINT(-74.006 40.7128)')),
       ('LAX001', 'Los Angeles Branch', '456 Sunset Blvd', 'Los Angeles', 'CA', '90028',
        ST_GeomFromText('POINT(-118.2437 34.0522)')),
       ('CHI001', 'Chicago Branch', '789 Michigan Ave', 'Chicago', 'IL', '60611',
        ST_GeomFromText('POINT(-87.6298 41.8781)'));

-- ============================================================================
-- GRANTS AND PERMISSIONS
-- ============================================================================

-- Create application user
CREATE USER IF NOT EXISTS 'banking_app'@'%' IDENTIFIED BY 'secure_password_change_me';
GRANT SELECT, INSERT, UPDATE ON banking.* TO 'banking_app'@'%';
GRANT EXECUTE ON PROCEDURE banking.create_account TO 'banking_app'@'%';
GRANT EXECUTE ON PROCEDURE banking.process_transfer TO 'banking_app'@'%';

-- Create read-only user for analytics
CREATE USER IF NOT EXISTS 'analytics_user'@'%' IDENTIFIED BY 'secure_password_change_me';
GRANT SELECT ON banking.* TO 'analytics_user'@'%';

-- Create admin user
CREATE USER IF NOT EXISTS 'banking_admin'@'localhost' IDENTIFIED BY 'secure_password_change_me';
GRANT ALL PRIVILEGES ON banking.* TO 'banking_admin'@'localhost';

FLUSH PRIVILEGES;

-- ============================================================================
SHOW TABLES;
SHOW TABLE STATUS;


-- Sample Data Inserts for Banking Schema

USE banking;

-- ============================================================================
-- CUSTOMERS
-- ============================================================================

INSERT INTO customers (customer_uuid, first_name, last_name, email, phone, date_of_birth, ssn_hash, address_line1,
                       address_line2, city, state, postal_code, country, status)
VALUES ('550e8400-e29b-41d4-a716-446655440001', 'John', 'Doe', 'john.doe@example.com', '+1-555-0101', '1985-03-15',
        SHA2('123-45-6789', 256), '123 Main Street', 'Apt 4B', 'New York', 'NY', '10001', 'US', 'ACTIVE'),
       ('550e8400-e29b-41d4-a716-446655440002', 'Jane', 'Smith', 'jane.smith@example.com', '+1-555-0102', '1990-07-22',
        SHA2('234-56-7890', 256), '456 Oak Avenue', NULL, 'Los Angeles', 'CA', '90028', 'US', 'ACTIVE'),
       ('550e8400-e29b-41d4-a716-446655440003', 'Michael', 'Johnson', 'michael.j@example.com', '+1-555-0103',
        '1988-11-08', SHA2('345-67-8901', 256), '789 Pine Road', 'Suite 200', 'Chicago', 'IL', '60611', 'US', 'ACTIVE'),
       ('550e8400-e29b-41d4-a716-446655440004', 'Sarah', 'Williams', 'sarah.w@example.com', '+1-555-0104', '1992-05-30',
        SHA2('456-78-9012', 256), '321 Elm Street', NULL, 'Houston', 'TX', '77001', 'US', 'ACTIVE'),
       ('550e8400-e29b-41d4-a716-446655440005', 'David', 'Brown', 'david.brown@example.com', '+1-555-0105',
        '1987-09-14', SHA2('567-89-0123', 256), '654 Maple Drive', 'Unit 5', 'Phoenix', 'AZ', '85001', 'US', 'ACTIVE');

-- ============================================================================
-- BRANCHES
-- ============================================================================

INSERT INTO branches (branch_code, branch_name, address_line1, address_line2, city, state, postal_code, country, phone,
                      email, location, timezone, status)
VALUES ('NYAC001', 'New York Main Branch', '123 Wall Street', 'Floor 10', 'New York', 'NY', '10005', 'US',
        '+1-212-555-1001', 'nyc001@banking.com', ST_GeomFromText('POINT(-74.006 40.7128)'), 'America/New_York',
        'ACTIVE'),
       ('LAEX001', 'Los Angeles Branch', '456 Sunset Blvd', NULL, 'Los Angeles', 'CA', '90028', 'US', '+1-323-555-2001',
        'lax001@banking.com', ST_GeomFromText('POINT(-118.2437 34.0522)'), 'America/Los_Angeles', 'ACTIVE'),
       ('CHIx001', 'Chicago Branch', '789 Michigan Ave', 'Suite 500', 'Chicago', 'IL', '60611', 'US', '+1-312-555-3001',
        'chi001@banking.com', ST_GeomFromText('POINT(-87.6298 41.8781)'), 'America/Chicago', 'ACTIVE'),
       ('HOUx001', 'Houston Branch', '321 Main Street', NULL, 'Houston', 'TX', '77001', 'US', '+1-713-555-4001',
        'hou001@banking.com', ST_GeomFromText('POINT(-95.3698 29.7604)'), 'America/Chicago', 'ACTIVE'),
       ('PHX0x01', 'Phoenix Branch', '654 Central Ave', NULL, 'Phoenix', 'AZ', '85001', 'US', '+1-602-555-5001',
        'phx001@banking.com', ST_GeomFromText('POINT(-112.0740 33.4484)'), 'America/Phoenix', 'ACTIVE');


SELECT branch_id, branch_code, branch_name
FROM branches
WHERE branch_code = 'NYC001';

SELECT * From branches;

-- ============================================================================
-- MERCHANTS
-- ============================================================================

INSERT INTO merchants (merchant_code, merchant_name, merchant_category, location, status)
VALUES ('MCH001', 'Amazon.com', 'E-commerce', ST_GeomFromText('POINT(-122.3319 47.6062)'), 'ACTIVE'),
       ('MCH002', 'Starbucks Coffee', 'Food & Beverage', ST_GeomFromText('POINT(-122.3308 47.6062)'), 'ACTIVE'),
       ('MCH003', 'Walmart Supercenter', 'Retail', ST_GeomFromText('POINT(-96.7970 32.7767)'), 'ACTIVE'),
       ('MCH004', 'Shell Gas Station', 'Gas Station', ST_GeomFromText('POINT(-74.0060 40.7128)'), 'ACTIVE'),
       ('MCH005', 'Target Store', 'Retail', ST_GeomFromText('POINT(-118.2437 34.0522)'), 'ACTIVE'),
       ('MCH006', 'Uber Technologies', 'Transportation', ST_GeomFromText('POINT(-122.4194 37.7749)'), 'ACTIVE'),
       ('MCH007', 'Netflix', 'Entertainment', ST_GeomFromText('POINT(-122.0574 37.3875)'), 'ACTIVE'),
       ('MCH008', 'Apple Store', 'Electronics', ST_GeomFromText('POINT(-122.4064 37.7879)'), 'ACTIVE');

-- ============================================================================
-- ACCOUNTS
-- ============================================================================

INSERT INTO accounts (account_number, customer_id, account_type, balance, available_balance, currency, interest_rate,
                      opened_date, status)
VALUES ('ACC0000000001', 1, 'CHECKING', 5000.00, 5000.00, 'USD', 0.0000, '2020-01-15', 'ACTIVE'),
       ('ACC0000000002', 1, 'SAVINGS', 25000.00, 25000.00, 'USD', 0.0100, '2020-02-01', 'ACTIVE'),
       ('ACC0000000003', 2, 'CHECKING', 3500.00, 3500.00, 'USD', 0.0000, '2021-03-10', 'ACTIVE'),
       ('ACC0000000004', 2, 'SAVINGS', 15000.00, 15000.00, 'USD', 0.0100, '2021-03-10', 'ACTIVE'),
       ('ACC0000000005', 3, 'CHECKING', 7500.00, 7500.00, 'USD', 0.0000, '2019-06-20', 'ACTIVE'),
       ('ACC0000000006', 3, 'CREDIT', -500.00, 9500.00, 'USD', 0.1800, '2022-01-05', 'ACTIVE'),
       ('ACC0000000007', 4, 'CHECKING', 12000.00, 12000.00, 'USD', 0.0000, '2021-08-12', 'ACTIVE'),
       ('ACC0000000008', 5, 'CHECKING', 2800.00, 2800.00, 'USD', 0.0000, '2023-02-14', 'ACTIVE'),
       ('ACC0000000009', 5, 'SAVINGS', 8000.00, 8000.00, 'USD', 0.0100, '2023-02-14', 'ACTIVE');

-- ============================================================================
-- ATMs
-- ============================================================================

INSERT INTO atms (atm_code, branch_id, location_name, address_line1, city, state, postal_code, location, status)
VALUES ('ATM01', 1, 'Wall Street ATM', '123 Wall Street', 'New York', 'NY', '10005',
        ST_GeomFromText('POINT(-74.006 40.7128)'), 'ACTIVE'),
       ('ATM02', 1, 'Times Square ATM', '1500 Broadway', 'New York', 'NY', '10036',
        ST_GeomFromText('POINT(-73.9851 40.7580)'), 'ACTIVE'),
       ('ATM03', 2, 'Sunset Blvd ATM', '456 Sunset Blvd', 'Los Angeles', 'CA', '90028',
        ST_GeomFromText('POINT(-118.2437 34.0522)'), 'ACTIVE'),
       ('ATM04', 3, 'Michigan Ave ATM', '789 Michigan Ave', 'Chicago', 'IL', '60611',
        ST_GeomFromText('POINT(-87.6298 41.8781)'), 'ACTIVE'),
       ('ATM05', NULL, 'Standalone ATM - Houston', '500 Main Street', 'Houston', 'TX', '77001',
        ST_GeomFromText('POINT(-95.3698 29.7604)'), 'ACTIVE');

-- ============================================================================
-- TRANSACTIONS
-- ============================================================================

INSERT INTO transactions (transaction_uuid, account_id, customer_id, transaction_type, amount, balance_after, currency,
                          description, reference_number, merchant_id, transaction_date, posted_date, status,
                          fraud_score)
VALUES (UUID(), 1, 1, 'DEPOSIT', 5000.00, 5000.00, 'USD', 'Initial account deposit', 'DEP001', NULL,
        '2020-01-15 10:00:00', '2020-01-15 10:00:00', 'COMPLETED', 0.1),
       (UUID(), 2, 1, 'DEPOSIT', 25000.00, 25000.00, 'USD', 'Initial savings deposit', 'DEP002', NULL,
        '2020-02-01 14:30:00', '2020-02-01 14:30:00', 'COMPLETED', 0.1),
       (UUID(), 1, 1, 'PAYMENT', -150.00, 4850.00, 'USD', 'Payment to Amazon.com', 'PAY001', 1, '2024-01-10 09:15:00',
        '2024-01-10 09:15:00', 'COMPLETED', 0.2),
       (UUID(), 1, 1, 'PAYMENT', -5.50, 4844.50, 'USD', 'Starbucks Coffee purchase', 'PAY002', 2, '2024-01-12 08:30:00',
        '2024-01-12 08:30:00', 'COMPLETED', 0.1),
       (UUID(), 3, 2, 'DEPOSIT', 3500.00, 3500.00, 'USD', 'Initial account deposit', 'DEP003', NULL,
        '2021-03-10 11:00:00', '2021-03-10 11:00:00', 'COMPLETED', 0.1),
       (UUID(), 4, 2, 'DEPOSIT', 15000.00, 15000.00, 'USD', 'Initial savings deposit', 'DEP004', NULL,
        '2021-03-10 11:05:00', '2021-03-10 11:05:00', 'COMPLETED', 0.1),
       (UUID(), 3, 2, 'PAYMENT', -89.99, 3410.01, 'USD', 'Walmart purchase', 'PAY003', 3, '2024-01-15 16:45:00',
        '2024-01-15 16:45:00', 'COMPLETED', 0.2),
       (UUID(), 5, 3, 'DEPOSIT', 7500.00, 7500.00, 'USD', 'Initial account deposit', 'DEP005', NULL,
        '2019-06-20 13:20:00', '2019-06-20 13:20:00', 'COMPLETED', 0.1),
       (UUID(), 6, 3, 'PAYMENT', -500.00, -500.00, 'USD', 'Credit card purchase', 'PAY004', 8, '2024-01-08 10:00:00',
        '2024-01-08 10:00:00', 'COMPLETED', 0.3),
       (UUID(), 7, 4, 'DEPOSIT', 12000.00, 12000.00, 'USD', 'Initial account deposit', 'DEP006', NULL,
        '2021-08-12 15:00:00', '2021-08-12 15:00:00', 'COMPLETED', 0.1),
       (UUID(), 7, 4, 'PAYMENT', -15.00, 11985.00, 'USD', 'Uber ride', 'PAY005', 6, '2024-01-18 18:30:00',
        '2024-01-18 18:30:00', 'COMPLETED', 0.2),
       (UUID(), 8, 5, 'DEPOSIT', 2800.00, 2800.00, 'USD', 'Initial account deposit', 'DEP007', NULL,
        '2023-02-14 09:00:00', '2023-02-14 09:00:00', 'COMPLETED', 0.1),
       (UUID(), 9, 5, 'DEPOSIT', 8000.00, 8000.00, 'USD', 'Initial savings deposit', 'DEP008', NULL,
        '2023-02-14 09:05:00', '2023-02-14 09:05:00', 'COMPLETED', 0.1),
       (UUID(), 1, 1, 'TRANSFER', -1000.00, 3844.50, 'USD', 'Transfer to savings account', 'TRF001', NULL,
        '2024-01-20 10:00:00', '2024-01-20 10:00:00', 'COMPLETED', 0.1),
       (UUID(), 2, 1, 'TRANSFER', 1000.00, 26000.00, 'USD', 'Transfer from checking account', 'TRF001', NULL,
        '2024-01-20 10:00:00', '2024-01-20 10:00:00', 'COMPLETED', 0.1),
       (UUID(), 1, 1, 'FEE', -5.00, 3839.50, 'USD', 'Monthly maintenance fee', 'FEE001', NULL, '2024-01-31 00:00:00',
        '2024-01-31 00:00:00', 'COMPLETED', NULL),
       (UUID(), 2, 1, 'INTEREST', 25.00, 26025.00, 'USD', 'Monthly interest payment', 'INT001', NULL,
        '2024-01-31 00:00:00', '2024-01-31 00:00:00', 'COMPLETED', NULL);

-- Update related_transaction_id for transfer transactions
UPDATE transactions
SET related_transaction_id = 15
WHERE transaction_id = 14;
UPDATE transactions
SET related_transaction_id = 14
WHERE transaction_id = 15;

-- ============================================================================
-- CUSTOMER CORRESPONDENCE
-- ============================================================================

INSERT INTO customer_correspondence (customer_id, correspondence_type, subject, body, direction, created_by, created_at)
VALUES (1, 'EMAIL', 'Welcome to Banking Platform',
        'Dear John Doe, Welcome to our banking platform. Your account has been successfully created.', 'OUTBOUND',
        'system@banking.com', '2020-01-15 10:05:00'),
       (1, 'EMAIL', 'Account Statement - January 2024',
        'Your monthly account statement for January 2024 is now available.', 'OUTBOUND', 'system@banking.com',
        '2024-02-01 00:00:00'),
       (2, 'EMAIL', 'Welcome to Banking Platform',
        'Dear Jane Smith, Welcome to our banking platform. Your account has been successfully created.', 'OUTBOUND',
        'system@banking.com', '2021-03-10 11:10:00'),
       (1, 'PHONE', 'Fraud Alert Follow-up',
        'Called customer to verify recent transaction. Customer confirmed transaction was legitimate.', 'INBOUND',
        'fraud_team@banking.com', '2024-01-10 14:30:00'),
       (3, 'CHAT', 'Question about credit card', 'Customer asked about credit card interest rates and payment options.',
        'INBOUND', 'customer_service@banking.com', '2024-01-08 15:20:00'),
       (4, 'EMAIL', 'Account Security Update',
        'We have updated your account security settings. Please review your preferences.', 'OUTBOUND',
        'security@banking.com', '2024-01-15 09:00:00');

-- ============================================================================
-- AUDIT LOG
-- ============================================================================

INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, user_id, ip_address, user_agent,
                       created_at)
VALUES ('accounts', 1, 'UPDATE', JSON_OBJECT('balance', 5000.00, 'status', 'PENDING'),
        JSON_OBJECT('balance', 5000.00, 'status', 'ACTIVE'), 'banking_app', '192.168.1.100', 'BankingApp/1.0',
        '2020-01-15 10:00:00'),
       ('accounts', 1, 'UPDATE', JSON_OBJECT('balance', 5000.00, 'status', 'ACTIVE'),
        JSON_OBJECT('balance', 4850.00, 'status', 'ACTIVE'), 'banking_app', '192.168.1.100', 'BankingApp/1.0',
        '2024-01-10 09:15:00'),
       ('accounts', 1, 'UPDATE', JSON_OBJECT('balance', 4850.00, 'status', 'ACTIVE'),
        JSON_OBJECT('balance', 4844.50, 'status', 'ACTIVE'), 'banking_app', '192.168.1.100', 'BankingApp/1.0',
        '2024-01-12 08:30:00'),
       ('accounts', 1, 'UPDATE', JSON_OBJECT('balance', 4844.50, 'status', 'ACTIVE'),
        JSON_OBJECT('balance', 3844.50, 'status', 'ACTIVE'), 'banking_app', '192.168.1.100', 'BankingApp/1.0',
        '2024-01-20 10:00:00'),
       ('accounts', 2, 'UPDATE', JSON_OBJECT('balance', 26000.00, 'status', 'ACTIVE'),
        JSON_OBJECT('balance', 26025.00, 'status', 'ACTIVE'), 'banking_app', '192.168.1.100', 'BankingApp/1.0',
        '2024-01-31 00:00:00'),
       ('customers', 1, 'UPDATE', JSON_OBJECT('status', 'PENDING'), JSON_OBJECT('status', 'ACTIVE'), 'banking_admin',
        '10.0.0.1', 'AdminPanel/2.0', '2020-01-15 10:00:00'),
       ('transactions', 3, 'INSERT', NULL, JSON_OBJECT('transaction_id', 3, 'amount', -150.00, 'status', 'COMPLETED'),
        'banking_app', '192.168.1.100', 'BankingApp/1.0', '2024-01-10 09:15:00');

-- ============================================================================
-- USER PERMISSIONS
-- ============================================================================

INSERT INTO user_permissions (user_id, customer_ids, role)
VALUES ('analyst@banking.com', JSON_ARRAY(1, 2, 3, 4, 5), 'fraud_analyst'),
       ('service@banking.com', JSON_ARRAY(1, 2), 'customer_service'),
       ('service2@banking.com', JSON_ARRAY(3, 4, 5), 'customer_service'),
       ('admin@banking.com', JSON_ARRAY(1, 2, 3, 4, 5), 'admin'),
       ('manager@banking.com', JSON_ARRAY(1, 2, 3, 4, 5), 'manager');

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify data was inserted correctly
SELECT 'Customers' AS table_name, COUNT(*) AS record_count
FROM customers
UNION ALL
SELECT 'Accounts', COUNT(*)
FROM accounts
UNION ALL
SELECT 'Transactions', COUNT(*)
FROM transactions
UNION ALL
SELECT 'Branches', COUNT(*)
FROM branches
UNION ALL
SELECT 'ATMs', COUNT(*)
FROM atms
UNION ALL
SELECT 'Merchants', COUNT(*)
FROM merchants
UNION ALL
SELECT 'Customer Correspondence', COUNT(*)
FROM customer_correspondence
UNION ALL
SELECT 'Audit Log', COUNT(*)
FROM audit_log
UNION ALL
SELECT 'User Permissions', COUNT(*)
FROM user_permissions;

-- View customer account summary (view)
SELECT *
FROM customer_account_summary
LIMIT 5;

-- View transaction summary daily (view)
SELECT *
FROM transaction_summary_daily
WHERE transaction_date >= '2024-01-01'
LIMIT 10;





