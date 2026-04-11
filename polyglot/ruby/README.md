# Ruby

`mysql2` gem patterns for Rails-adjacent or standalone services.

## Contents

| Doc | Description |
| --- | ----------- |
| [SAGA_MYSQL2.md](./SAGA_MYSQL2.md) | Idempotent debit with `mysql2` |

## Roles (this folder)

| Role | Responsibility |
| ---- | ---------------- |
| **Language Maintainer** | Documents compatibility with Rails connection handling if embedded. |
| **SRE** | Pool via `connection_pool` gem or Puma thread math. |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
