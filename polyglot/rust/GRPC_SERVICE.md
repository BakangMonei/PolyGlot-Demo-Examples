# Rust: tonic `LedgerService`

Proto and governance: [`../shared/GRPC_TRANSFER_PROTO.md`](../shared/GRPC_TRANSFER_PROTO.md).

## Service Skeleton

```rust
use tonic::{Request, Response, Status};

pub mod transfer {
    tonic::include_proto!("banking.transfer.v1");
}

use transfer::ledger_server::Ledger;
use transfer::{DebitCommand, DebitReply, debit_reply::Status};

#[derive(Default)]
pub struct LedgerSvc;

#[tonic::async_trait]
impl Ledger for LedgerSvc {
    async fn debit(
        &self,
        req: Request<DebitCommand>,
    ) -> Result<Response<DebitReply>, Status> {
        let _cmd = req.into_inner();
        // Call Ledger::debit_if_absent from CLIENTS.md; map duplicate -> DUPLICATE
        Ok(Response::new(DebitReply {
            status: Status::Applied as i32,
            reason: String::new(),
        }))
    }
}
```

## Roles

| Role                     | Notes                                               |
| ------------------------ | --------------------------------------------------- |
| **Language Maintainer**  | Pins `tonic` / `prost` versions and documents MSRV. |
| **API / Contract Owner** | Owns breaking proto changes.                        |
