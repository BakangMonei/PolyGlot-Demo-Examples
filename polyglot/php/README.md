# PHP

PDO-based patterns for legacy stacks and LAMP-style services. Keep **strict types** and prepared statements mandatory.

## Contents

| Doc | Description |
| --- | ----------- |
| [SAGA_PDO.md](./SAGA_PDO.md) | Idempotent debit with PDO transactions |

## Roles (this folder)

| Role | Responsibility |
| ---- | ---------------- |
| **Language Maintainer** | Documents PHP version support (8.x+) and `pdo_mysql` extensions. |
| **Security Reviewer** | Blocks dynamic SQL; reviews session fixation and header handling for idempotency keys. |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
