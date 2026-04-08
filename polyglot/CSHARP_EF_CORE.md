# C# with EF Core (Pomelo MySQL Provider)

EF Core is appropriate when migrations, LINQ, and model-first workflows dominate. For **hot-path OLTP** with extreme latency targets, many teams still drop to Dapper or raw ADO.NET as shown in [CSHARP.md](./CSHARP.md).

## DbContext Sketch

```csharp
using Microsoft.EntityFrameworkCore;

public sealed class BankingContext : DbContext
{
    public BankingContext(DbContextOptions<BankingContext> options) : base(options) { }

    public DbSet<LedgerOperation> LedgerOperations => Set<LedgerOperation>();
    public DbSet<Account> Accounts => Set<Account>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<LedgerOperation>(b =>
        {
            b.ToTable("ledger_operations");
            b.HasKey(x => x.Id);
            b.HasIndex(x => x.IdempotencyKey).IsUnique();
        });

        modelBuilder.Entity<Account>(b =>
        {
            b.ToTable("accounts");
            b.HasKey(x => x.AccountId);
        });
    }
}

public sealed class LedgerOperation
{
    public long Id { get; set; }
    public string IdempotencyKey { get; set; } = "";
    public long AccountId { get; set; }
    public long AmountMinor { get; set; }
    public string OpType { get; set; } = "";
    public string CorrelationId { get; set; } = "";
}

public sealed class Account
{
    public long AccountId { get; set; }
    public long Balance { get; set; }
    public long AvailableBalance { get; set; }
}
```

## Idempotent Debit with Execution Strategy + Transaction

```csharp
using Microsoft.EntityFrameworkCore;

public sealed class EfLedgerRepository
{
    private readonly BankingContext _db;

    public EfLedgerRepository(BankingContext db) => _db = db;

    public async Task<bool> DebitIfAbsentAsync(
        long accountId,
        long amountMinor,
        string idempotencyKey,
        string correlationId,
        CancellationToken ct = default)
    {
        var strategy = _db.Database.CreateExecutionStrategy();

        return await strategy.ExecuteAsync(async () =>
        {
            await using var tx = await _db.Database.BeginTransactionAsync(ct);

            _db.LedgerOperations.Add(new LedgerOperation
            {
                IdempotencyKey = idempotencyKey,
                AccountId = accountId,
                AmountMinor = amountMinor,
                OpType = "DEBIT",
                CorrelationId = correlationId
            });

            try
            {
                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                await tx.RollbackAsync(ct);
                return false; // duplicate idempotency key
            }

            var affected = await _db.Database.ExecuteSqlInterpolatedAsync(
                $"""
                 UPDATE accounts
                 SET balance = balance - {amountMinor},
                     available_balance = available_balance - {amountMinor}
                 WHERE account_id = {accountId}
                   AND available_balance >= {amountMinor}
                 """,
                ct);

            if (affected != 1)
            {
                await tx.RollbackAsync(ct);
                throw new InvalidOperationException("Insufficient funds or missing account");
            }

            await tx.CommitAsync(ct);
            return true;
        });
    }
}
```

> For **true** `INSERT IGNORE` semantics via EF alone, prefer raw SQL (`ExecuteSqlRaw`) for the insert leg, or catch duplicate key on `SaveChanges` as shown.

## MongoDB with EF Core?

EF Core targets relational stores. For MongoDB, continue using **MongoDB.Driver** (see [CSHARP.md](./CSHARP.md)) or the official EF Core MongoDB provider when its feature set matches your governance requirements.
