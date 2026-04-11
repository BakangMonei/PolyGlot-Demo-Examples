CREATE TABLE IF NOT EXISTS audit_log (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    actor VARCHAR(128) NOT NULL,
    action VARCHAR(64) NOT NULL,
    entity VARCHAR(64) NOT NULL,
    entity_id VARCHAR(64) NOT NULL,
    payload JSON NULL,
    correlation_id CHAR(36) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    INDEX idx_audit_entity (entity, entity_id),
    INDEX idx_audit_correlation (correlation_id),
    INDEX idx_audit_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
