# C#: grpc-dotnet `LedgerService`

Proto: [`../shared/GRPC_TRANSFER_PROTO.md`](../shared/GRPC_TRANSFER_PROTO.md).

## Service Implementation

```csharp
using Banking.Transfer.V1;
using Grpc.Core;

public class LedgerService : Ledger.LedgerBase
{
    private readonly LedgerRepository _ledger;

    public LedgerService(LedgerRepository ledger) => _ledger = ledger;

    public override async Task<DebitReply> Debit(DebitCommand request, ServerCallContext context)
    {
        try
        {
            var applied = await _ledger.DebitIfAbsentAsync(
                request.FromAccountId,
                request.AmountMinor,
                request.IdempotencyKey,
                request.CorrelationId,
                context.CancellationToken);

            return new DebitReply
            {
                Status = applied ? DebitReply.Types.Status.Applied : DebitReply.Types.Status.Duplicate
            };
        }
        catch (Exception ex)
        {
            return new DebitReply { Status = DebitReply.Types.Status.Rejected, Reason = ex.Message };
        }
    }
}
```

`LedgerRepository` is defined in [ADONET.md](./ADONET.md).

## Roles

| Role | Notes |
| ---- | ----- |
| **API / Contract Owner** | Owns proto versioning. |
| **Language Maintainer** | Keeps `Grpc.AspNetCore` and generator packages aligned. |
