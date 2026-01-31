-- MySQL 8.0 Banking Schema
-- System of Record - Financial Transactions

-- Enable required features
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET default_time_zone = '+00:00';

-- Create database
CREATE DATABASE IF NOT EXISTS banking CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE banking;

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Customers table
CREATE TABLE customers (
  customer_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  customer_uuid CHAR(36) NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(20),
  date_of_birth DATE NOT NULL,
  ssn_hash VARCHAR(64) NOT NULL COMMENT 'SHA-256 hash of SSN',
  address_line1 VARCHAR(255),
  address_line2 VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(50),
  postal_code VARCHAR(20),
  country VARCHAR(2) DEFAULT 'US',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status ENUM('ACTIVE', 'INACTIVE', 'SUSPENDED', 'CLOSED') DEFAULT 'ACTIVE',
  INDEX idx_email (email),
  INDEX idx_status (status),
  INDEX idx_created_at (created_at),
  FULLTEXT INDEX idx_name (first_name, last_name) WITH PARSER ngram
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Customer master data';

-- Accounts table
CREATE TABLE accounts (
  account_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  account_number VARCHAR(20) NOT NULL UNIQUE,
  customer_id BIGINT UNSIGNED NOT NULL,
  account_type ENUM('CHECKING', 'SAVINGS', 'CREDIT', 'LOAN', 'INVESTMENT') NOT NULL,
  balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
  available_balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
  currency VARCHAR(3) DEFAULT 'USD',
  interest_rate DECIMAL(5,4) DEFAULT 0.0000,
  opened_date DATE NOT NULL,
  closed_date DATE NULL,
  status ENUM('ACTIVE', 'FROZEN', 'CLOSED', 'PENDING') DEFAULT 'ACTIVE',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
  INDEX idx_customer_id (customer_id),
  INDEX idx_account_number (account_number),
  INDEX idx_status (status),
  INDEX idx_opened_date (opened_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Account master data';

-- Transactions table (time-series optimized)
CREATE TABLE transactions (
  transaction_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  transaction_uuid CHAR(36) NOT NULL UNIQUE,
  account_id BIGINT UNSIGNED NOT NULL,
  customer_id BIGINT UNSIGNED NOT NULL,
  transaction_type ENUM('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'PAYMENT', 'FEE', 'INTEREST', 'REFUND') NOT NULL,
  amount DECIMAL(20,2) NOT NULL,
  balance_after DECIMAL(20,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'USD',
  description VARCHAR(500),
  reference_number VARCHAR(100),
  related_transaction_id BIGINT UNSIGNED NULL,
  merchant_id BIGINT UNSIGNED NULL,
  transaction_date TIMESTAMP NOT NULL,
  posted_date TIMESTAMP NULL,
  status ENUM('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED', 'REVERSED') DEFAULT 'PENDING',
  fraud_score DECIMAL(5,4) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Audit hash for compliance
  audit_hash VARCHAR(64) AS (
    SHA2(CONCAT(
      transaction_id, '|',
      account_id, '|',
      customer_id, '|',
      transaction_type, '|',
      amount, '|',
      transaction_date, '|',
      status
    ), 256)
  ) STORED,
  FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE RESTRICT,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
  FOREIGN KEY (related_transaction_id) REFERENCES transactions(transaction_id) ON DELETE SET NULL,
  INDEX idx_account_id (account_id),
  INDEX idx_customer_id (customer_id),
  INDEX idx_transaction_date (transaction_date),
  INDEX idx_status (status),
  INDEX idx_transaction_type (transaction_type),
  INDEX idx_audit_hash (audit_hash),
  INDEX idx_related_transaction (related_transaction_id),
  -- Composite index for common queries
  INDEX idx_customer_date_type (customer_id, transaction_date DESC, transaction_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Transaction history with audit trail';

-- Partition transactions by year for better performance
ALTER TABLE transactions PARTITION BY RANGE (YEAR(transaction_date)) (
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
CREATE TABLE branches (
  branch_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  branch_code VARCHAR(10) NOT NULL UNIQUE,
  branch_name VARCHAR(100) NOT NULL,
  address_line1 VARCHAR(255),
  address_line2 VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(50),
  postal_code VARCHAR(20),
  country VARCHAR(2) DEFAULT 'US',
  phone VARCHAR(20),
  email VARCHAR(255),
  location POINT NOT NULL COMMENT 'Geographic coordinates',
  timezone VARCHAR(50) DEFAULT 'UTC',
  status ENUM('ACTIVE', 'INACTIVE', 'CLOSED') DEFAULT 'ACTIVE',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  SPATIAL INDEX idx_location (location),
  INDEX idx_branch_code (branch_code),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Branch locations with spatial indexing';

-- ATMs table (with spatial data)
CREATE TABLE atms (
  atm_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  atm_code VARCHAR(10) NOT NULL UNIQUE,
  branch_id INT UNSIGNED NULL,
  location_name VARCHAR(100),
  address_line1 VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(50),
  postal_code VARCHAR(20),
  location POINT NOT NULL,
  status ENUM('ACTIVE', 'INACTIVE', 'OUT_OF_SERVICE') DEFAULT 'ACTIVE',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE SET NULL,
  SPATIAL INDEX idx_location (location),
  INDEX idx_atm_code (atm_code),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='ATM locations';

-- Merchants table
CREATE TABLE merchants (
  merchant_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  merchant_code VARCHAR(20) NOT NULL UNIQUE,
  merchant_name VARCHAR(255) NOT NULL,
  merchant_category VARCHAR(100),
  location POINT NULL,
  status ENUM('ACTIVE', 'INACTIVE', 'BLACKLISTED') DEFAULT 'ACTIVE',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_merchant_code (merchant_code),
  INDEX idx_status (status),
  SPATIAL INDEX idx_location (location)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Merchant information';

-- ============================================================================
-- AUDIT AND COMPLIANCE TABLES
-- ============================================================================

-- Customer correspondence table (for full-text search)
CREATE TABLE customer_correspondence (
  correspondence_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  correspondence_type ENUM('EMAIL', 'LETTER', 'PHONE', 'CHAT', 'IN_PERSON') NOT NULL,
  subject VARCHAR(500),
  body TEXT,
  direction ENUM('INBOUND', 'OUTBOUND') NOT NULL,
  created_by VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
  INDEX idx_customer_id (customer_id),
  INDEX idx_created_at (created_at),
  FULLTEXT INDEX idx_fulltext (subject, body) WITH PARSER ngram
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Customer correspondence with full-text search';

-- Audit log table
CREATE TABLE audit_log (
  audit_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  table_name VARCHAR(100) NOT NULL,
  record_id BIGINT UNSIGNED NOT NULL,
  action ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  old_values JSON NULL,
  new_values JSON NULL,
  user_id VARCHAR(100) NOT NULL,
  ip_address VARCHAR(45),
  user_agent VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_table_record (table_name, record_id),
  INDEX idx_user_id (user_id),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Comprehensive audit trail';

-- ============================================================================
-- ROW-LEVEL SECURITY TABLES
-- ============================================================================

-- User permissions table for RLS
CREATE TABLE user_permissions (
  user_id VARCHAR(100) PRIMARY KEY,
  customer_ids JSON NOT NULL COMMENT 'Array of customer IDs user can access',
  role VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User permissions for row-level security';

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Customer account summary view
CREATE VIEW customer_account_summary AS
SELECT 
  c.customer_id,
  c.first_name,
  c.last_name,
  c.email,
  COUNT(DISTINCT a.account_id) as total_accounts,
  SUM(CASE WHEN a.status = 'ACTIVE' THEN 1 ELSE 0 END) as active_accounts,
  SUM(a.balance) as total_balance,
  SUM(a.available_balance) as total_available_balance,
  MAX(a.opened_date) as latest_account_opened
FROM customers c
LEFT JOIN accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email;

-- Transaction summary view (for analytics)
CREATE VIEW transaction_summary_daily AS
SELECT 
  DATE(transaction_date) as transaction_date,
  customer_id,
  transaction_type,
  COUNT(*) as transaction_count,
  SUM(amount) as total_amount,
  AVG(amount) as avg_amount,
  MIN(amount) as min_amount,
  MAX(amount) as max_amount
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
  IN p_account_type ENUM('CHECKING', 'SAVINGS', 'CREDIT', 'LOAN', 'INVESTMENT'),
  IN p_initial_balance DECIMAL(20,2),
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
  INSERT INTO accounts (
    account_number,
    customer_id,
    account_type,
    balance,
    available_balance,
    opened_date,
    status
  ) VALUES (
    p_account_number,
    p_customer_id,
    p_account_type,
    p_initial_balance,
    p_initial_balance,
    CURDATE(),
    'ACTIVE'
  );
  
  SET p_account_id = LAST_INSERT_ID();
  
  -- Create initial transaction if balance > 0
  IF p_initial_balance > 0 THEN
    INSERT INTO transactions (
      transaction_uuid,
      account_id,
      customer_id,
      transaction_type,
      amount,
      balance_after,
      transaction_date,
      posted_date,
      status,
      description
    ) VALUES (
      UUID(),
      p_account_id,
      p_customer_id,
      'DEPOSIT',
      p_initial_balance,
      p_initial_balance,
      NOW(),
      NOW(),
      'COMPLETED',
      'Initial account deposit'
    );
  END IF;
  
  COMMIT;
END//

-- Procedure to process a transfer
CREATE PROCEDURE process_transfer(
  IN p_from_account_id BIGINT UNSIGNED,
  IN p_to_account_id BIGINT UNSIGNED,
  IN p_amount DECIMAL(20,2),
  IN p_description VARCHAR(500),
  OUT p_transaction_id BIGINT UNSIGNED,
  OUT p_status VARCHAR(20)
)
BEGIN
  DECLARE v_from_customer_id BIGINT UNSIGNED;
  DECLARE v_to_customer_id BIGINT UNSIGNED;
  DECLARE v_from_balance DECIMAL(20,2);
  DECLARE v_to_balance DECIMAL(20,2);
  DECLARE v_transaction_uuid CHAR(36);
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_status = 'FAILED';
    RESIGNAL;
  END;
  
  START TRANSACTION;
  
  -- Get account information
  SELECT customer_id, available_balance INTO v_from_customer_id, v_from_balance
  FROM accounts
  WHERE account_id = p_from_account_id AND status = 'ACTIVE'
  FOR UPDATE;
  
  SELECT customer_id, balance INTO v_to_customer_id, v_to_balance
  FROM accounts
  WHERE account_id = p_to_account_id AND status = 'ACTIVE'
  FOR UPDATE;
  
  -- Validate sufficient balance
  IF v_from_balance < p_amount THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
  END IF;
  
  SET v_transaction_uuid = UUID();
  
  -- Debit from account
  UPDATE accounts
  SET balance = balance - p_amount,
      available_balance = available_balance - p_amount,
      updated_at = NOW()
  WHERE account_id = p_from_account_id;
  
  -- Credit to account
  UPDATE accounts
  SET balance = balance + p_amount,
      available_balance = available_balance + p_amount,
      updated_at = NOW()
  WHERE account_id = p_to_account_id;
  
  -- Create debit transaction
  INSERT INTO transactions (
    transaction_uuid,
    account_id,
    customer_id,
    transaction_type,
    amount,
    balance_after,
    transaction_date,
    posted_date,
    status,
    description,
    related_transaction_id
  ) VALUES (
    v_transaction_uuid,
    p_from_account_id,
    v_from_customer_id,
    'TRANSFER',
    -p_amount,
    v_from_balance - p_amount,
    NOW(),
    NOW(),
    'COMPLETED',
    CONCAT('Transfer to account ', p_to_account_id, ': ', p_description),
    NULL
  );
  
  SET p_transaction_id = LAST_INSERT_ID();
  
  -- Create credit transaction
  INSERT INTO transactions (
    transaction_uuid,
    account_id,
    customer_id,
    transaction_type,
    amount,
    balance_after,
    transaction_date,
    posted_date,
    status,
    description,
    related_transaction_id
  ) VALUES (
    UUID(),
    p_to_account_id,
    v_to_customer_id,
    'TRANSFER',
    p_amount,
    v_to_balance + p_amount,
    NOW(),
    NOW(),
    'COMPLETED',
    CONCAT('Transfer from account ', p_from_account_id, ': ', p_description),
    p_transaction_id
  );
  
  -- Update related transaction
  UPDATE transactions
  SET related_transaction_id = LAST_INSERT_ID()
  WHERE transaction_id = p_transaction_id;
  
  SET p_status = 'COMPLETED';
  COMMIT;
END//

DELIMITER ;

-- ============================================================================
-- TRIGGERS FOR AUDIT LOGGING
-- ============================================================================

DELIMITER //

-- Trigger for account changes
CREATE TRIGGER accounts_audit_update
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
  IF OLD.balance != NEW.balance OR OLD.status != NEW.status THEN
    INSERT INTO audit_log (
      table_name,
      record_id,
      action,
      old_values,
      new_values,
      user_id
    ) VALUES (
      'accounts',
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
      USER()
    );
  END IF;
END//

DELIMITER ;

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- Insert sample branch data
INSERT INTO branches (branch_code, branch_name, address_line1, city, state, postal_code, location) VALUES
('NYC001', 'New York Main Branch', '123 Wall Street', 'New York', 'NY', '10005', ST_GeomFromText('POINT(-74.006 40.7128)')),
('LAX001', 'Los Angeles Branch', '456 Sunset Blvd', 'Los Angeles', 'CA', '90028', ST_GeomFromText('POINT(-118.2437 34.0522)')),
('CHI001', 'Chicago Branch', '789 Michigan Ave', 'Chicago', 'IL', '60611', ST_GeomFromText('POINT(-87.6298 41.8781)'));

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
