# Saga Idempotency Step: Index by Language

This index points to the **same logical step** everywhere: record idempotent intent in MySQL (`ledger_operations` with unique `idempotency_key`), then conditionally debit `accounts`. MongoDB projection updates belong **after** commit or via **outbox** (see `patterns/CQRS_PATTERN.md`).

## Preconditions

- `ledger_operations.idempotency_key` is **UNIQUE**.
- Prefer `INSERT IGNORE` for the insert leg (MySQL) or database-specific equivalent.

## Implementations by folder

| Language        | Primary doc                                                                        |
| --------------- | ---------------------------------------------------------------------------------- |
| Java            | [java/JDBC_CLIENTS.md](../java/JDBC_CLIENTS.md) — `LedgerRepository.debitIfAbsent` |
| Java (reactive) | [java/R2DBC_REACTIVE.md](../java/R2DBC_REACTIVE.md)                                |
| Rust            | [rust/CLIENTS.md](../rust/CLIENTS.md) — `Ledger::debit_if_absent`                  |
| C#              | [csharp/ADONET.md](../csharp/ADONET.md) — `LedgerRepository.DebitIfAbsentAsync`    |
| C# (EF Core)    | [csharp/EF_CORE.md](../csharp/EF_CORE.md)                                          |
| Go              | [go/CLIENTS.md](../go/CLIENTS.md)                                                  |
| Python          | [python/CLIENTS.md](../python/CLIENTS.md)                                          |
| TypeScript      | [typescript/MYSQL_MONGODB.md](../typescript/MYSQL_MONGODB.md)                      |
| Kotlin          | [kotlin/JDBC_CLIENTS.md](../kotlin/JDBC_CLIENTS.md)                                |
| Scala           | [scala/PEKKO_JDBC.md](../scala/PEKKO_JDBC.md)                                      |
| Dart            | [dart/CLIENTS.md](../dart/CLIENTS.md)                                              |
| PHP             | [php/SAGA_PDO.md](../php/SAGA_PDO.md)                                              |
| Ruby            | [ruby/SAGA_MYSQL2.md](../ruby/SAGA_MYSQL2.md)                                      |
| Elixir          | [elixir/SAGA_ECTO.md](../elixir/SAGA_ECTO.md)                                      |

Full choreography remains in [`../../patterns/SAGA_PATTERN.md`](../../patterns/SAGA_PATTERN.md).
