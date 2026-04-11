# C#: MySqlConnector + MongoDB.Driver

## Recommended Packages

| Database | Package                                                        |
| -------- | -------------------------------------------------------------- |
| MySQL    | [MySqlConnector](https://github.com/mysql-net/MySqlConnector)  |
| MongoDB  | [MongoDB.Driver](https://www.mongodb.com/docs/drivers/csharp/) |

## MySqlConnector + Idempotent Debit (`INSERT IGNORE`)

```csharp
using System.Data;
using System.Threading;
using System.Threading.Tasks;
using MySqlConnector;

public sealed class LedgerRepository
{
    private readonly string _connectionString;

    public LedgerRepository(string connectionString)
    {
        _connectionString = connectionString;
    }

    /// <summary>Returns true if debit applied; false if idempotency key already processed.</summary>
    public async Task<bool> DebitIfAbsentAsync(
        long accountId,
        long amountMinor,
        string idempotencyKey,
        string correlationId,
        CancellationToken ct = default)
    {
        await using var conn = new MySqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);

        const string insertOp = """
            INSERT IGNORE INTO ledger_operations
              (idempotency_key, account_id, amount_minor, op_type, correlation_id)
            VALUES (@k, @a, @m, 'DEBIT', @c)
            """;

        await using (var ins = new MySqlCommand(insertOp, conn, (MySqlTransaction)tx))
        {
            ins.Parameters.AddWithValue("@k", idempotencyKey);
            ins.Parameters.AddWithValue("@a", accountId);
            ins.Parameters.AddWithValue("@m", amountMinor);
            ins.Parameters.AddWithValue("@c", correlationId);

            var inserted = await ins.ExecuteNonQueryAsync(ct);
            if (inserted == 0)
            {
                await tx.RollbackAsync(ct);
                return false;
            }
        }

        const string applyDebit = """
            UPDATE accounts
            SET balance = balance - @m,
                available_balance = available_balance - @m
            WHERE account_id = @a
              AND available_balance >= @m
            """;

        await using (var upd = new MySqlCommand(applyDebit, conn, (MySqlTransaction)tx))
        {
            upd.Parameters.AddWithValue("@m", amountMinor);
            upd.Parameters.AddWithValue("@a", accountId);
            var rows = await upd.ExecuteNonQueryAsync(ct);
            if (rows != 1)
            {
                await tx.RollbackAsync(ct);
                throw new InvalidOperationException("Insufficient funds or missing account.");
            }
        }

        await tx.CommitAsync(ct);
        return true;
    }
}
```

## MongoDB.Driver Projection

```csharp
using MongoDB.Bson;
using MongoDB.Driver;

public sealed class Customer360Repository
{
    private readonly IMongoCollection<BsonDocument> _customers;

    public Customer360Repository(IMongoDatabase db)
    {
        _customers = db.GetCollection<BsonDocument>("customers");
    }

    public async Task AppendTransferAsync(
        string customerId,
        string transferId,
        long amountMinor,
        string currency,
        CancellationToken ct = default)
    {
        var filter = Builders<BsonDocument>.Filter.Eq("customer_id", customerId);
        var push = Builders<BsonDocument>.Update.Push(
            "recent_transfers",
            new BsonDocument
            {
                { "transfer_id", transferId },
                { "amount_minor", amountMinor },
                { "currency", currency },
                { "occurred_at", DateTime.UtcNow }
            });
        var touch = Builders<BsonDocument>.Update.Set("last_updated_at", DateTime.UtcNow);

        await _customers.UpdateOneAsync(filter, Builders<BsonDocument>.Update.Combine(push, touch),
            cancellationToken: ct);
    }
}
```

## ASP.NET Core Minimal API Wiring

```csharp
using MongoDB.Driver;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton(_ =>
{
    var cs = builder.Configuration.GetConnectionString("mysql")
             ?? throw new InvalidOperationException("mysql connection string missing");
    return new LedgerRepository(cs);
});

builder.Services.AddSingleton<IMongoClient>(_ =>
    new MongoClient(builder.Configuration["Mongo:Uri"]));

builder.Services.AddSingleton(sp =>
{
    var client = sp.GetRequiredService<IMongoClient>();
    return client.GetDatabase("banking_engagement");
});

builder.Services.AddSingleton<Customer360Repository>();

var app = builder.Build();

app.MapPost("/transfers/{idempotencyKey}/debit", async (
    string idempotencyKey,
    DebitRequest body,
    LedgerRepository ledger,
    CancellationToken ct) =>
{
    var applied = await ledger.DebitIfAbsentAsync(
        body.AccountId, body.AmountMinor, idempotencyKey, body.CorrelationId, ct);

    return applied ? Results.Accepted() : Results.NoContent();
});

app.Run();

public sealed record DebitRequest(long AccountId, long AmountMinor, string CorrelationId);
```

## Change Streams (`IAsyncEnumerable`)

```csharp
using MongoDB.Bson;
using MongoDB.Driver;

public static class TransactionTail
{
    public static async Task RunAsync(IMongoCollection<BsonDocument> txs, CancellationToken ct)
    {
        var pipeline = new EmptyPipelineDefinition<ChangeStreamDocument<BsonDocument>>();
        using var cursor = await txs.WatchAsync(pipeline, cancellationToken: ct);

        await foreach (var change in cursor.ToAsyncEnumerable().WithCancellation(ct))
        {
            _ = change.ResumeToken;
        }
    }
}
```

## Observability

- **OpenTelemetry.Instrumentation.SqlClient** for ADO.NET spans.
- MongoDB driver diagnostic listeners so Mongo calls share trace IDs with HTTP ingress.
