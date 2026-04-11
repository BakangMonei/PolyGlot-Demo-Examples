# Rust

Async-first clients using **`sqlx`** for MySQL and the official **`mongodb`** crate for engagement data.

## Contents

| Doc                                  | Description                                                          |
| ------------------------------------ | -------------------------------------------------------------------- |
| [CLIENTS.md](./CLIENTS.md)           | Pool setup, idempotent debit, Mongo projection, change stream sketch |
| [GRPC_SERVICE.md](./GRPC_SERVICE.md) | `tonic` server stub for shared `LedgerService` proto                 |

## Roles (this folder)

| Role                    | Responsibility                                                                                                                      |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Language Maintainer** | Keeps `sqlx` offline mode / CI story documented; validates `Cargo` feature flags for TLS.                                           |
| **Security Reviewer**   | Reviews `unsafe` usage (should be none in samples) and TLS for `DATABASE_URL`.                                                      |
| **SRE**                 | Aligns `max_connections` and Mongo pool settings with [`../shared/RESILIENCE_AND_POOLING.md`](../shared/RESILIENCE_AND_POOLING.md). |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
