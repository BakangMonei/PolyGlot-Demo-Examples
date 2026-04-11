-- Extend audit trail for multi-service correlation (RLS remains application-layer)
ALTER TABLE audit_log
    ADD COLUMN source_service VARCHAR(64) NULL COMMENT 'polyglot service name' AFTER correlation_id;
