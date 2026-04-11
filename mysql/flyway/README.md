# Flyway (Java toolchain)

SQL migrations live in `sql/`. Run via Docker (see root `docker-compose.yml`) or locally:

```bash
docker run --rm \
  -v "$PWD/sql:/flyway/sql" \
  flyway/flyway:10-alpine \
  -url=jdbc:mysql://host.docker.internal:3306/financial_platform \
  -user=root -password="$MYSQL_ROOT_PASSWORD" \
  migrate
```

## Stored procedures and triggers

MySQL **DELIMITER** blocks are often applied with `mysql` CLI rather than JDBC. For production, manage complex routines via:

- `mysql/schemas/` DBA-reviewed scripts, or
- Flyway **callbacks** / separate pipeline.

This repo ships **V9** as a **VIEW** (`v_account_balance_from_ledger`) for balance derivation demos.

## Rollback

Rollback scripts for each version live in `rollback/` (idempotent `DROP` / `ALTER` reversals). See `migrations/MIGRATION_PLAYBOOK.md`.
