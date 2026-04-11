-- Double-entry bookkeeping: each transaction has balanced ledger lines
CREATE TABLE IF NOT EXISTS ledger_entries (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    transaction_id VARCHAR(36) NOT NULL,
    account_id VARCHAR(36) NOT NULL,
    debit_minor BIGINT NOT NULL DEFAULT 0,
    credit_minor BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ledger_tx FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE RESTRICT,
    CONSTRAINT fk_ledger_account FOREIGN KEY (account_id) REFERENCES accounts (id),
    CONSTRAINT chk_ledger_one_side CHECK (
        (debit_minor > 0 AND credit_minor = 0) OR (credit_minor > 0 AND debit_minor = 0)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_ledger_account ON ledger_entries (account_id);
