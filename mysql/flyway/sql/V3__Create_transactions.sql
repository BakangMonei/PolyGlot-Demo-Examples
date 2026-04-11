CREATE TABLE IF NOT EXISTS transactions (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    account_id VARCHAR(36) NOT NULL,
    amount_minor BIGINT NOT NULL,
    type ENUM ('debit', 'credit', 'transfer') NOT NULL,
    status ENUM ('posted', 'pending', 'rejected') NOT NULL DEFAULT 'posted',
    counterparty_account_id VARCHAR(36) NULL,
    narrative VARCHAR(512) NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    correlation_id CHAR(36) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_transactions_idempotency (idempotency_key),
    CONSTRAINT fk_transactions_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_transactions_account_created ON transactions (account_id, created_at);
