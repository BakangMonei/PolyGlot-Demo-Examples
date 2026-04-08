# gRPC / Protobuf Contracts Across Java, Rust, C#, and Others

When multiple runtimes participate in the same saga, **stable wire contracts** matter more than in-process DTOs. This file shows a minimal `TransferCommand` proto and idiomatic server stubs.

## `transfer.proto`

```protobuf
syntax = "proto3";

package banking.transfer.v1;

option java_multiple_files = true;
option csharp_namespace = "Banking.Transfer.V1";

message DebitCommand {
  string idempotency_key = 1;
  int64 from_account_id = 2;
  int64 amount_minor = 3;
  string correlation_id = 4;
}

message DebitReply {
  enum Status {
    STATUS_UNSPECIFIED = 0;
    APPLIED = 1;
    DUPLICATE = 2;
    REJECTED = 3;
  }
  Status status = 1;
  string reason = 2; // populated when REJECTED
}

service LedgerService {
  rpc Debit(DebitCommand) returns (DebitReply);
}
```

## Java (grpc-java) Server Skeleton

```java
import banking.transfer.v1.DebitReply;
import banking.transfer.v1.LedgerGrpc;
import io.grpc.stub.StreamObserver;

public final class LedgerGrpcService extends LedgerGrpc.LedgerImplBase {
  private final LedgerRepository ledger;

  public LedgerGrpcService(LedgerRepository ledger) {
    this.ledger = ledger;
  }

  @Override
  public void debit(
      banking.transfer.v1.DebitCommand request, StreamObserver<DebitReply> responseObserver) {
    try {
      boolean applied =
          ledger.debitIfAbsent(
              request.getFromAccountId(),
              request.getAmountMinor(),
              request.getIdempotencyKey(),
              request.getCorrelationId());

      var reply =
          DebitReply.newBuilder()
              .setStatus(applied ? DebitReply.Status.APPLIED : DebitReply.Status.DUPLICATE)
              .build();
      responseObserver.onNext(reply);
      responseObserver.onCompleted();
    } catch (Exception e) {
      responseObserver.onNext(
          DebitReply.newBuilder()
              .setStatus(DebitReply.Status.REJECTED)
              .setReason(e.getMessage())
              .build());
      responseObserver.onCompleted();
    }
  }
}
```

## Rust (tonic) Service Skeleton

```rust
use tonic::{Request, Response, Status};

pub mod transfer {
    tonic::include_proto!("banking.transfer.v1");
}

use transfer::ledger_server::{Ledger, LedgerServer};
use transfer::{DebitReply, DebitCommand, debit_reply::Status};

#[derive(Default)]
pub struct LedgerSvc;

#[tonic::async_trait]
impl Ledger for LedgerSvc {
    async fn debit(
        &self,
        req: Request<DebitCommand>,
    ) -> Result<Response<DebitReply>, Status> {
        let _ = req.into_inner();
        // call sqlx ledger here; map duplicate -> DUPLICATE
        Ok(Response::new(DebitReply {
            status: Status::Applied as i32,
            reason: String::new(),
        }))
    }
}
```

## C# (grpc-dotnet) Program Excerpt

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

## Go (`google.golang.org/grpc`)

Use `protoc-gen-go` and `protoc-gen-go-grpc` with the same `.proto`. Keep **generated code** in CI artifacts so reviewers can diff API changes.

## Contract Governance

- Treat proto fields as **append-only**; reserve deleted numbers.
- Run **breaking change detection** (`buf breaking`, `apilinter`) in pull requests.
- Version packages as `banking.transfer.v1`, `v2`, never reuse semantics under the same version.
