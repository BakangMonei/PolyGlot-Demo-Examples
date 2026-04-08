# Additional Runtimes (Go, Python, TypeScript, Kotlin)

Short, production-aligned snippets mirroring the same **idempotent debit + engagement projection** contracts as [JAVA.md](./JAVA.md), [RUST.md](./RUST.md), and [CSHARP.md](./CSHARP.md).

---

## Go (`database/sql` + official `mongo-go-driver`)

```go
package ledger

import (
	"context"
	"database/sql"
	"errors"
)

type Repository struct {
	DB *sql.DB
}

// DebitIfAbsent returns applied=false when idempotency key already exists.
func (r *Repository) DebitIfAbsent(ctx context.Context, accountID, amount int64, idempotencyKey, correlationID string) (applied bool, err error) {
	tx, err := r.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback() }()

	const ins = `
INSERT IGNORE INTO ledger_operations
  (idempotency_key, account_id, amount_minor, op_type, correlation_id)
VALUES (?, ?, ?, 'DEBIT', ?)`

	res, err := tx.ExecContext(ctx, ins, idempotencyKey, accountID, amount, correlationID)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return false, nil
	}

	const upd = `
UPDATE accounts
SET balance = balance - ?,
    available_balance = available_balance - ?
WHERE account_id = ?
  AND available_balance >= ?`

	res2, err := tx.ExecContext(ctx, upd, amount, amount, accountID, amount)
	if err != nil {
		return false, err
	}
	changed, _ := res2.RowsAffected()
	if changed != 1 {
		return false, errors.New("insufficient funds or missing account")
	}
	if err := tx.Commit(); err != nil {
		return false, err
	}
	return true, nil
}
```

The deferred `Rollback` runs after `Commit`; on success it usually yields `sql.ErrTxDone`, which is ignored with `_`.

```go
package engagement

import (
	"context"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

func AppendTransfer(ctx context.Context, col *mongo.Collection, customerID, transferID string, amount int64, currency string) error {
	_, err := col.UpdateOne(ctx,
		bson.M{"customer_id": customerID},
		bson.M{
			"$push": bson.M{"recent_transfers": bson.M{
				"transfer_id":  transferID,
				"amount_minor": amount,
				"currency":     currency,
				"occurred_at":  time.Now().UTC(),
			}},
			"$set": bson.M{"last_updated_at": time.Now().UTC()},
		},
	)
	return err
}
```

---

## Python (`mysqlclient` / PyMySQL + `pymongo`)

```python
from contextlib import contextmanager
import pymysql
from pymongo import MongoClient

class LedgerRepository:
    def __init__(self, conn_params: dict):
        self._conn_params = conn_params

    @contextmanager
    def _conn(self):
        conn = pymysql.connect(**self._conn_params)
        try:
            yield conn
        finally:
            conn.close()

    def debit_if_absent(self, account_id: int, amount_minor: int, idempotency_key: str, correlation_id: str) -> bool:
        with self._conn() as conn:
            conn.begin()
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT IGNORE INTO ledger_operations
                          (idempotency_key, account_id, amount_minor, op_type, correlation_id)
                        VALUES (%s, %s, %s, 'DEBIT', %s)
                        """,
                        (idempotency_key, account_id, amount_minor, correlation_id),
                    )
                    if cur.rowcount == 0:
                        conn.rollback()
                        return False

                    cur.execute(
                        """
                        UPDATE accounts
                        SET balance = balance - %s,
                            available_balance = available_balance - %s
                        WHERE account_id = %s
                          AND available_balance >= %s
                        """,
                        (amount_minor, amount_minor, account_id, amount_minor),
                    )
                    if cur.rowcount != 1:
                        conn.rollback()
                        raise RuntimeError("Insufficient funds or missing account")

                conn.commit()
                return True
            except Exception:
                conn.rollback()
                raise
```

```python
def append_transfer(db, customer_id: str, transfer_id: str, amount_minor: int, currency: str) -> None:
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    db["customers"].update_one(
        {"customer_id": customer_id},
        {
            "$push": {
                "recent_transfers": {
                    "transfer_id": transfer_id,
                    "amount_minor": amount_minor,
                    "currency": currency,
                    "occurred_at": now,
                }
            },
            "$set": {"last_updated_at": now},
        },
    )
```

---

## TypeScript / Node.js (`mysql2/promise` + `mongodb`)

```typescript
import mysql from "mysql2/promise";
import { MongoClient } from "mongodb";

export class LedgerRepository {
  constructor(private readonly pool: mysql.Pool) {}

  async debitIfAbsent(
    accountId: bigint,
    amountMinor: bigint,
    idempotencyKey: string,
    correlationId: string
  ): Promise<boolean> {
    const conn = await this.pool.getConnection();
    try {
      await conn.beginTransaction();
      const [ins] = await conn.execute<mysql.ResultSetHeader>(
        `INSERT IGNORE INTO ledger_operations
           (idempotency_key, account_id, amount_minor, op_type, correlation_id)
         VALUES (?, ?, ?, 'DEBIT', ?)`,
        [idempotencyKey, accountId, amountMinor, correlationId]
      );
      if (ins.affectedRows === 0) {
        await conn.rollback();
        return false;
      }

      const [upd] = await conn.execute<mysql.ResultSetHeader>(
        `UPDATE accounts
         SET balance = balance - ?,
             available_balance = available_balance - ?
         WHERE account_id = ?
           AND available_balance >= ?`,
        [amountMinor, amountMinor, accountId, amountMinor]
      );
      if (upd.affectedRows !== 1) {
        await conn.rollback();
        throw new Error("Insufficient funds or missing account");
      }

      await conn.commit();
      return true;
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  }
}
```

```typescript
export async function appendTransfer(
  mongo: MongoClient,
  customerId: string,
  transferId: string,
  amountMinor: number,
  currency: string
) {
  const col = mongo.db("banking_engagement").collection("customers");
  await col.updateOne(
    { customer_id: customerId },
    {
      $push: {
        recent_transfers: {
          transfer_id: transferId,
          amount_minor: amountMinor,
          currency,
          occurred_at: new Date(),
        },
      },
      $set: { last_updated_at: new Date() },
    }
  );
}
```

---

## Kotlin (JDBC + `use` blocks)

```kotlin
import java.sql.Connection
import java.sql.DriverManager

class LedgerRepository(private val jdbcUrl: String, private val user: String, private val password: String) {

    fun debitIfAbsent(
        accountId: Long,
        amountMinor: Long,
        idempotencyKey: String,
        correlationId: String
    ): Boolean = DriverManager.getConnection(jdbcUrl, user, password).use { conn ->
        conn.autoCommit = false
        try {
            conn.prepareStatement(
                """
                INSERT IGNORE INTO ledger_operations
                  (idempotency_key, account_id, amount_minor, op_type, correlation_id)
                VALUES (?, ?, ?, 'DEBIT', ?)
                """.trimIndent()
            ).use { ps ->
                ps.setString(1, idempotencyKey)
                ps.setLong(2, accountId)
                ps.setLong(3, amountMinor)
                ps.setString(4, correlationId)
                if (ps.executeUpdate() == 0) {
                    conn.rollback()
                    return@use false
                }
            }

            conn.prepareStatement(
                """
                UPDATE accounts
                SET balance = balance - ?,
                    available_balance = available_balance - ?
                WHERE account_id = ?
                  AND available_balance >= ?
                """.trimIndent()
            ).use { ps ->
                ps.setLong(1, amountMinor)
                ps.setLong(2, amountMinor)
                ps.setLong(3, accountId)
                ps.setLong(4, amountMinor)
                check(ps.executeUpdate() == 1) { "Insufficient funds or missing account" }
            }

            conn.commit()
            true
        } catch (t: Throwable) {
            conn.rollback()
            throw t
        }
    }
}
```

---

## When to Choose Which

| Runtime | Strength in this architecture |
| ------- | ----------------------------- |
| Go | Small binaries, excellent concurrency for tailers and edge proxies |
| Python | Rapid internal tooling, ML adjacency for fraud scoring services |
| TypeScript | Shared types with BFFs, rich JSON ergonomics for customer 360 APIs |
| Kotlin | JVM interop with existing Java banking cores, coroutine clarity |
