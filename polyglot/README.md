# Polyglot Application Clients

This directory complements the hybrid MySQL + MongoDB architecture with **production-oriented client patterns** across multiple runtimes. Each guide assumes the same logical contracts as `patterns/` (Saga, CQRS, idempotency) and the schemas in `mysql/schemas/` and `mongodb/schemas/`.

## Guides

| Guide | Focus |
| ----- | ----- |
| [JAVA.md](./JAVA.md) | JDBC + HikariCP, Spring-style layering, MongoDB Java Driver, observability hooks |
| [JAVA_R2DBC_REACTIVE.md](./JAVA_R2DBC_REACTIVE.md) | WebFlux-style R2DBC + reactive MongoDB projections |
| [RUST.md](./RUST.md) | `sqlx`, `mongodb` crate, `tokio`, change streams, compile-time checked SQL |
| [CSHARP.md](./CSHARP.md) | `MySqlConnector`, `MongoDB.Driver`, minimal APIs, `IAsyncEnumerable` change streams |
| [CSHARP_EF_CORE.md](./CSHARP_EF_CORE.md) | EF Core models, execution strategies, hybrid raw SQL for hot paths |
| [OTHER_LANGUAGES.md](./OTHER_LANGUAGES.md) | Go, Python, TypeScript, Kotlin: drivers, pooling, async models |
| [NESTJS_TYPESCRIPT.md](./NESTJS_TYPESCRIPT.md) | NestJS modules, guards, MySQL + Mongo wiring |
| [SCALA_PEKKO.md](./SCALA_PEKKO.md) | Scala 3 + Pekko HTTP + JDBC / Java driver interop |
| [DART_FLUTTER.md](./DART_FLUTTER.md) | Dart / Flutter BFF patterns for MySQL + MongoDB |
| [RESILIENCE_AND_POOLING.md](./RESILIENCE_AND_POOLING.md) | Cross-language timeouts, pools, retries, circuit breakers |
| [GRPC_AND_CONTRACTS.md](./GRPC_AND_CONTRACTS.md) | Protobuf + gRPC stubs for Java, Rust, C#, and governance |
| [POLYGLOT_SAGA_SNIPPETS.md](./POLYGLOT_SAGA_SNIPPETS.md) | Same “debit ledger + project read model” step in several languages |

## Cross-Cutting Rules (All Runtimes)

1. **System of record first**: commit MySQL before publishing “facts” that MongoDB consumers rely on, or use outbox + projector ordering guarantees documented in `patterns/CQRS_PATTERN.md`.
2. **Idempotency**: every command carries `idempotency_key` (header or column); unique constraint in MySQL prevents double spend.
3. **Timeouts + cancellation**: propagate deadlines (OpenTelemetry context, `CancellationToken`, `Context::with_deadline`, etc.).
4. **Secrets**: never embed DSN passwords in samples; use vault references or environment variables.

## Related Repository Docs

- [Technical Architecture](../architecture/TECHNICAL_ARCHITECTURE.md)
- [Saga Pattern](../patterns/SAGA_PATTERN.md)
- [CQRS Pattern](../patterns/CQRS_PATTERN.md)
- [MySQL Setup](../mysql/SETUP.md)
- [MongoDB Setup](../mongodb/SETUP.md)
- [Observability](../observability/SETUP.md)
