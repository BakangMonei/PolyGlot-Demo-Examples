# Kotlin

JVM interop with Java cores, with concise **JDBC** or **Exposed** access patterns. Often used for Android-adjacent services or Ktor BFFs.

## Contents

| Doc | Description |
| --- | ----------- |
| [JDBC_CLIENTS.md](./JDBC_CLIENTS.md) | Idempotent debit with `use` blocks |
| [INTEROP.md](./INTEROP.md) | Calling Java `LedgerRepository` from Kotlin |

## Roles (this folder)

| Role | Responsibility |
| ---- | ---------------- |
| **Language Maintainer** | Documents coroutine dispatchers for blocking JDBC. |
| **Polyglot Architect** | Ensures Kotlin services share the same idempotency contract as Java modules. |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
