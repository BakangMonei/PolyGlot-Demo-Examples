# Java: gRPC `LedgerService`

Wire contract: [`../shared/GRPC_TRANSFER_PROTO.md`](../shared/GRPC_TRANSFER_PROTO.md).

## Server Skeleton (grpc-java)

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

`LedgerRepository` is the JDBC implementation from [JDBC_CLIENTS.md](./JDBC_CLIENTS.md).

## Roles

| Role | Notes |
| ---- | ----- |
| **API / Contract Owner** | Approves `.proto` changes; see [`../ROLES.md`](../ROLES.md). |
| **Language Maintainer** | Keeps generated package paths and grpc-java versions current. |
