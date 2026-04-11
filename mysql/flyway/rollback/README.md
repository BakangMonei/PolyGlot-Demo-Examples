# Flyway rollback scripts (manual / paired)

Paired rollback naming: `U10__Audit_source_column.sql` style per org standard.
For this demo, capture reverse DDL before production promotion:

| Version | Rollback action |
| ------- | ---------------- |
| V10 | `ALTER TABLE audit_log DROP COLUMN source_service;` |
| V9 | `DROP VIEW IF EXISTS v_account_balance_from_ledger;` |
| V8 | `DROP TABLE IF EXISTS idempotency_keys;` |
| V7 | `DELETE FROM accounts WHERE id LIKE 'demo-%';` |
| V6 | drop indexes created in V6 |
| V5 | `DROP TABLE audit_log;` |
| V4 | `DROP TABLE ledger_entries;` |
| V3 | `DROP TABLE transactions;` |
| V2 | `DROP TABLE accounts;` |
| V1 | `DROP TABLE user_roles; DROP TABLE roles; DROP TABLE users;` |
