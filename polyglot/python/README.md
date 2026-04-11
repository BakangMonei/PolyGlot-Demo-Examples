# Python

Fast iteration for tooling, ML-adjacent fraud services, and internal consoles. Prefer **parameterized** queries and explicit transactions for ledger code.

## Contents

| Doc | Description |
| --- | ----------- |
| [CLIENTS.md](./CLIENTS.md) | PyMySQL idempotent debit + `pymongo` projection |
| [PACKAGING.md](./PACKAGING.md) | Optional layout for services vs libraries |

## Roles (this folder)

| Role | Responsibility |
| ---- | ---------------- |
| **Language Maintainer** | Chooses one supported stack per service (`asyncpg` teams differ—document clearly). |
| **Security Reviewer** | Blocks f-strings in SQL; enforces dependency scanning (pip-audit, etc.). |
| **Polyglot Architect** | Ensures async services still respect saga ordering when mixed with Celery workers. |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
