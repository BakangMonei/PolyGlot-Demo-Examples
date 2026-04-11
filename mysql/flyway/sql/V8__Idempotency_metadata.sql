-- Optional metadata for gateway / service coordination (idempotent replays)
CREATE TABLE IF NOT EXISTS idempotency_keys (
    idempotency_key VARCHAR(128) NOT NULL PRIMARY KEY,
    response_code SMALLINT NOT NULL,
    response_body JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    INDEX idx_idem_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
