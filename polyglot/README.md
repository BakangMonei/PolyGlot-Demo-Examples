# Polyglot Application Clients

This directory is **documentation for implementers**: per-runtime notes, responsibilities (**[ROLES.md](./ROLES.md)**), and **illustrative code** for how a team might access MySQL (system of record) and MongoDB (system of engagement) in each language. It is not a mandate to ship every snippet as production code—adapt naming, drivers, and security controls to your own standards.

Repository-wide **HTTP/event contracts** you may copy into your own repos live at **[`../shared/`](../shared/README.md)** (OpenAPI, AsyncAPI, Protobuf, JSON Schema). The folder **`polyglot/shared/`** below holds only **cross-language** topics (resilience, gRPC stubs, saga index).

## Governance and roles

- **[ROLES.md](./ROLES.md)** — Polyglot Architect, Language Maintainer, Security, SRE, API / Contract Owner: who does what in reviews and incidents.
- **[polyglot/shared/README.md](./shared/README.md)** — Cross-runtime docs inside `polyglot/`:
  - [RESILIENCE_AND_POOLING.md](./shared/RESILIENCE_AND_POOLING.md)
  - [GRPC_TRANSFER_PROTO.md](./shared/GRPC_TRANSFER_PROTO.md)
  - [SAGA_IDEMPOTENCY_INDEX.md](./shared/SAGA_IDEMPOTENCY_INDEX.md)

## Language folders

| Folder                                | Entry                                         |
| ------------------------------------- | --------------------------------------------- |
| [java/](./java/README.md)             | JDBC, R2DBC, gRPC                             |
| [rust/](./rust/README.md)             | sqlx, mongodb crate, tonic                    |
| [csharp/](./csharp/README.md)         | MySqlConnector, MongoDB.Driver, EF Core, gRPC |
| [go/](./go/README.md)                 | database/sql, mongo-go-driver                 |
| [python/](./python/README.md)         | PyMySQL, pymongo, packaging                   |
| [typescript/](./typescript/README.md) | mysql2, mongodb, NestJS                       |
| [kotlin/](./kotlin/README.md)         | JDBC, Java interop                            |
| [dart/](./dart/README.md)             | Server/mobile patterns + security             |
| [scala/](./scala/README.md)           | Pekko HTTP + JDBC                             |
| [php/](./php/README.md)               | PDO saga step                                 |
| [ruby/](./ruby/README.md)             | mysql2 saga step                              |
| [elixir/](./elixir/README.md)         | Ecto / MyXQL saga step                        |

## Cross-cutting rules (all runtimes)

1. **System of record first**: commit MySQL before engagement projections, or use outbox ordering from `patterns/CQRS_PATTERN.md`.
2. **Idempotency**: every command carries `idempotency_key`; unique constraint in MySQL prevents double spend.
3. **Timeouts + cancellation**: propagate deadlines (OTel, `CancellationToken`, `context.Context`, etc.).
4. **Secrets**: never embed DSN passwords in samples; use vault references or environment variables.

## How to add a new language

1. Create `polyglot/<language>/README.md` with a short stack table, links to official drivers, and a **Roles** subsection (see [ROLES.md](./ROLES.md)).  
2. Add `CLIENTS.md` (or equivalent) with parameterized SQL / BSON examples—no real secrets.  
3. Register the saga idempotency step in [polyglot/shared/SAGA_IDEMPOTENCY_INDEX.md](./shared/SAGA_IDEMPOTENCY_INDEX.md).  
4. If the platform exposes gRPC, add a `GRPC_SERVICE.md` or link to `polyglot/shared/GRPC_TRANSFER_PROTO.md` and regenerate stubs in **your** repo.

## Related repository docs

- [Builders Guide](../BUILDERS_GUIDE.md)
- [Technical Architecture](../architecture/TECHNICAL_ARCHITECTURE.md)
- [Saga Pattern](../patterns/SAGA_PATTERN.md)
- [CQRS Pattern](../patterns/CQRS_PATTERN.md)
- [MySQL Setup](../mysql/SETUP.md)
- [MongoDB Setup](../mongodb/SETUP.md)
- [Observability](../observability/SETUP.md)
