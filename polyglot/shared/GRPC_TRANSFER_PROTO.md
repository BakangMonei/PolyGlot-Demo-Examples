# gRPC / Protobuf: Shared Wire Contract

Canonical proto and governance live here. **Per-language server and client stubs** live next to the runtime that implements them:

- [Java gRPC service](../java/GRPC_SERVICE.md)
- [Rust tonic service](../rust/GRPC_SERVICE.md)
- [C# grpc-dotnet service](../csharp/GRPC_SERVICE.md)

Other languages (Go, Kotlin, etc.) should generate code from this same `.proto` and link back from their folder READMEs when examples are added.

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

## Go (`google.golang.org/grpc`)

Use `protoc-gen-go` and `protoc-gen-go-grpc` with the same `.proto`. Keep **generated code** in CI artifacts so reviewers can diff API changes.

## Contract Governance

- Treat proto fields as **append-only**; reserve deleted numbers.
- Run **breaking change detection** (`buf breaking`, `apilinter`) in pull requests.
- Version packages as `banking.transfer.v1`, `v2`, never reuse semantics under the same version.

## Role

The **API / Contract Owner** (see [`../ROLES.md`](../ROLES.md)) approves changes to this file and coordinates stub regeneration across services.
