# Go

Small binaries and first-class **context** propagation make Go a strong fit for change-stream tailers, sidecars, and high-concurrency BFFs.

## Contents

| Doc                        | Description                                                    |
| -------------------------- | -------------------------------------------------------------- |
| [CLIENTS.md](./CLIENTS.md) | `database/sql` idempotent debit + `mongo-go-driver` projection |

## Roles (this folder)

| Role                    | Responsibility                                                                          |
| ----------------------- | --------------------------------------------------------------------------------------- |
| **Language Maintainer** | Standardizes on `database/sql` + official drivers; documents `sqlc` if adopted.         |
| **SRE**                 | Owns `SetMaxOpenConns` tuning and context timeout wrappers (see shared resilience doc). |
| **Security Reviewer**   | TLS for DSNs, no string-concat SQL.                                                     |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
- [`../shared/GRPC_TRANSFER_PROTO.md`](../shared/GRPC_TRANSFER_PROTO.md) — generate Go stubs from the same proto when exposing gRPC.
