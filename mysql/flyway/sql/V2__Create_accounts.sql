CREATE TABLE IF NOT EXISTS accounts (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    currency CHAR(3) NOT NULL,
    balance_minor BIGINT NOT NULL DEFAULT 0,
    status ENUM ('active', 'frozen', 'closed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_balance_nonnegative CHECK (balance_minor >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_accounts_status ON accounts (status);
