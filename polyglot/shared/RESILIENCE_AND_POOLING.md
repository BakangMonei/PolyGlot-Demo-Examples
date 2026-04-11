# Resilience, Pooling, and Cross-Language Defaults

This guide standardizes **timeouts**, **pool sizing**, and **retry policy** for services calling MySQL (SoR) and MongoDB (SoE) regardless of implementation language.

## Connection Pools

| Runtime | MySQL pool | Mongo pool |
| ------- | ---------- | ---------- |
| Java | HikariCP `maximumPoolSize` ≈ `(threads * 1.2)` capped by DB `max_connections` budget | Mongo client: tune `maxPoolSize` per service |
| Rust | `sqlx::pool` `max_connections` same heuristic | `ClientOptions::max_pool_size` |
| C# | `MySqlDataSource` builder / pool limits | `MongoClientSettings` max connection pool size |
| Go | `sql.DB.SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime` | `mongooptions.Client().SetMaxPoolSize` |
| Node | `mysql2` pool `connectionLimit`, `queueLimit` | `MongoClient` `maxPoolSize` in URI or options |

**Rule of thumb:** pool size is **not** equal to RPS. Size for concurrent _in-flight_ queries at peak, then add 20% headroom.

## Timeouts

```text
Client connect timeout   : 2–5s
Statement / socket read  : 200–800ms for OLTP hot paths (higher for batch)
Idle connection eviction : < backend wait_timeout
```

Map these to:

- **Java**: Hikari `connectionTimeout`, JDBC `socketTimeout`, driver properties.
- **Rust**: `MySqlConnectOptions::timeout`, statement timeouts via session variables or `SET max_execution_time`.
- **C#**: `Connection Timeout=` in connection string; `CommandTimeout` per command.
- **Go**: `context.WithTimeout` around `QueryContext` / `ExecContext`.

## Retries: What Is Safe

| Operation | Automatic retry |
| --------- | ----------------- |
| Read-only `SELECT` | Yes, with jittered exponential backoff |
| `INSERT IGNORE` idempotency registration + `UPDATE` in one transaction | **No** mid-transaction retry; retry whole transaction only if the failure was a **transient disconnect before commit** |
| MongoDB `updateOne` with **monotonic** business condition | Only if the filter encodes expected version / `expected_mod_count` pattern |

## Circuit Breaking

Use a shared library in each ecosystem (Resilience4j, Polly, `gobreaker`, etc.) keyed by **dependency name** (`mysql-ledger`, `mongo-engagement`) with:

- Failure ratio threshold over rolling window
- Half-open probe with single concurrent call
- Metrics export consistent with `observability/SETUP.md`

## Example: Go Context Timeout Wrapper

```go
func WithOlapTimeout(parent context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(parent, 750*time.Millisecond)
}
```

## Example: C# Polly Around Read Repository

```csharp
var breaker = new Polly.CircuitBreaker.AsyncCircuitBreakerPolicy(
    exceptionsAllowedBeforeBreaking: 5,
    durationOfBreak: TimeSpan.FromSeconds(20));

await breaker.ExecuteAsync(async ct =>
{
    await using var cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT balance FROM accounts WHERE account_id = @id";
    // ...
}, cancellationToken);
```

Document break-glass procedures (manual override) in `operations/TEAM_TOPOLOGY.md` handoffs.
