# Polyglot Application Clients

This directory complements the hybrid MySQL + MongoDB architecture with **production-oriented client patterns** per runtime. Each language folder has its own **README** (with role assignments), focused docs, and code examples aligned with `patterns/` and the schemas under `mysql/schemas/` and `mongodb/schemas/`.

## Governance and roles

- **[ROLES.md](./ROLES.md)** — Polyglot Architect, Language Maintainer, Security, SRE, API / Contract Owner: who does what in reviews and incidents.
- **[shared/README.md](./shared/README.md)** — Index of cross-runtime docs:
  - [RESILIENCE_AND_POOLING.md](./shared/RESILIENCE_AND_POOLING.md)
  - [GRPC_TRANSFER_PROTO.md](./shared/GRPC_TRANSFER_PROTO.md)
  - [SAGA_IDEMPOTENCY_INDEX.md](./shared/SAGA_IDEMPOTENCY_INDEX.md)

## Language folders

| Folder | Entry |
| ------ | ----- |
| [java/](./java/README.md) | JDBC, R2DBC, gRPC |
| [rust/](./rust/README.md) | sqlx, mongodb crate, tonic |
| [csharp/](./csharp/README.md) | MySqlConnector, MongoDB.Driver, EF Core, gRPC |
| [go/](./go/README.md) | database/sql, mongo-go-driver |
| [python/](./python/README.md) | PyMySQL, pymongo, packaging |
| [typescript/](./typescript/README.md) | mysql2, mongodb, NestJS |
| [kotlin/](./kotlin/README.md) | JDBC, Java interop |
| [dart/](./dart/README.md) | Server/mobile patterns + security |
| [scala/](./scala/README.md) | Pekko HTTP + JDBC |
| [php/](./php/README.md) | PDO saga step |
| [ruby/](./ruby/README.md) | mysql2 saga step |
| [elixir/](./elixir/README.md) | Ecto / MyXQL saga step |

## Cross-cutting rules (all runtimes)

1. **System of record first**: commit MySQL before engagement projections, or use outbox ordering from `patterns/CQRS_PATTERN.md`.
2. **Idempotency**: every command carries `idempotency_key`; unique constraint in MySQL prevents double spend.
3. **Timeouts + cancellation**: propagate deadlines (OTel, `CancellationToken`, `context.Context`, etc.).
4. **Secrets**: never embed DSN passwords in samples; use vault references or environment variables.

## Related repository docs

- [Technical Architecture](../architecture/TECHNICAL_ARCHITECTURE.md)
- [Saga Pattern](../patterns/SAGA_PATTERN.md)
- [CQRS Pattern](../patterns/CQRS_PATTERN.md)
- [MySQL Setup](../mysql/SETUP.md)
- [MongoDB Setup](../mongodb/SETUP.md)
- [Observability](../observability/SETUP.md)
