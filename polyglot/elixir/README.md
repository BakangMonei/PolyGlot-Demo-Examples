# Elixir

Ecto + MyXQL for transactional services with excellent **supervision** trees for tailers and projectors.

## Contents

| Doc                            | Description                                   |
| ------------------------------ | --------------------------------------------- |
| [SAGA_ECTO.md](./SAGA_ECTO.md) | `Repo.transaction` + `insert_all` on conflict |

## Roles (this folder)

| Role                    | Responsibility                                                       |
| ----------------------- | -------------------------------------------------------------------- |
| **Language Maintainer** | Documents OTP release configuration for DB pools.                    |
| **Polyglot Architect**  | Aligns projector crash/restart semantics with Kafka consumer groups. |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
