# Rust: sqlx + mongodb + tokio

## Recommended Crates

| Concern | Crate |
| ------- | ----- |
| MySQL | `sqlx` (runtime + compile-time checks with `offline` mode in CI) |
| MongoDB | `mongodb` (official), BSON via `bson` |
| Async runtime | `tokio` |
| Serialization | `serde`, `serde_json` |

## `sqlx` Pool + Idempotent Debit

```rust
use sqlx::mysql::MySqlPoolOptions;
use sqlx::{MySql, MySqlPool, Transaction};

pub async fn pool_from_env() -> Result<MySqlPool, sqlx::Error> {
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    MySqlPoolOptions::new()
        .max_connections(32)
        .connect(&url)
        .await
}

pub struct Ledger<'a> {
    pool: &'a MySqlPool,
}

impl<'a> Ledger<'a> {
    pub fn new(pool: &'a MySqlPool) -> Self {
        Self { pool }
    }

    /// Returns `Ok(true)` if debit applied, `Ok(false)` if idempotent duplicate.
    pub async fn debit_if_absent(
        &self,
        account_id: i64,
        amount_minor: i64,
        idempotency_key: &str,
        correlation_id: &str,
    ) -> Result<bool, sqlx::Error> {
        let mut tx: Transaction<'_, MySql> = self.pool.begin().await?;

        let inserted = sqlx::query(
            r#"
            INSERT IGNORE INTO ledger_operations
              (idempotency_key, account_id, amount_minor, op_type, correlation_id)
            VALUES (?, ?, ?, 'DEBIT', ?)
            "#,
        )
        .bind(idempotency_key)
        .bind(account_id)
        .bind(amount_minor)
        .bind(correlation_id)
        .execute(&mut *tx)
        .await?
        .rows_affected();

        if inserted == 0 {
            tx.rollback().await?;
            return Ok(false);
        }

        let res = sqlx::query(
            r#"
            UPDATE accounts
            SET balance = balance - ?,
                available_balance = available_balance - ?
            WHERE account_id = ?
              AND available_balance >= ?
            "#,
        )
        .bind(amount_minor)
        .bind(amount_minor)
        .bind(account_id)
        .bind(amount_minor)
        .execute(&mut *tx)
        .await?;

        if res.rows_affected() != 1 {
            tx.rollback().await?;
            return Err(sqlx::Error::RowNotFound);
        }

        tx.commit().await?;
        Ok(true)
    }
}
```

## MongoDB Projection Update

```rust
use bson::{doc, DateTime};
use mongodb::{options::ClientOptions, Client, Collection};

#[derive(serde::Serialize, serde::Deserialize, Clone)]
struct TransferSnippet {
    transfer_id: String,
    amount_minor: i64,
    currency: String,
    occurred_at: bson::DateTime,
}

pub struct Customer360 {
    col: Collection<serde_json::Value>,
}

impl Customer360 {
    pub async fn connect(uri: &str) -> anyhow::Result<Self> {
        let mut opts = ClientOptions::parse(uri).await?;
        opts.app_name = Some("banking-engagement-rust".into());
        let client = Client::with_options(opts)?;
        let col = client
            .database("banking_engagement")
            .collection::<serde_json::Value>("customers");
        Ok(Self { col })
    }

    pub async fn append_transfer(
        &self,
        customer_id: &str,
        snippet: TransferSnippet,
    ) -> anyhow::Result<()> {
        let filter = doc! { "customer_id": customer_id };
        let update = doc! {
            "$push": { "recent_transfers": bson::to_bson(&snippet)? },
            "$set": { "last_updated_at": DateTime::now() }
        };
        self.col.update_one(filter, update, None).await?;
        Ok(())
    }
}
```

## Change Stream Consumer (Sketch)

```rust
use bson::Document;
use futures::StreamExt;
use mongodb::options::ChangeStreamOptions;
use mongodb::Collection;

pub async fn tail_transactions(collection: Collection<Document>) -> anyhow::Result<()> {
    let opts = ChangeStreamOptions::builder().build();
    let mut cs = collection.watch(None, opts).await?;

    while let Some(evt) = cs.next().await {
        let evt = evt?;
        let _token = evt.id;
    }
    Ok(())
}
```

## Safety and Performance Notes

- Enable **`sqlx` offline mode** in CI so builds do not require a live database.
- Prefer **`try_join!`** for independent reads; never parallelize two writes to the same saga without ordering rules.
- For **CPU-bound** BSON work in hot paths, consider `tokio::task::spawn_blocking` when profiling shows contention.
