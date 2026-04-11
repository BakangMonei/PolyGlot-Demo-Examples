# TypeScript: mysql2 + mongodb

## MySQL: Idempotent Debit

```typescript
import mysql from "mysql2/promise";

export class LedgerRepository {
  constructor(private readonly pool: mysql.Pool) {}

  async debitIfAbsent(
    accountId: bigint,
    amountMinor: bigint,
    idempotencyKey: string,
    correlationId: string,
  ): Promise<boolean> {
    const conn = await this.pool.getConnection();
    try {
      await conn.beginTransaction();
      const [ins] = await conn.execute<mysql.ResultSetHeader>(
        `INSERT IGNORE INTO ledger_operations
           (idempotency_key, account_id, amount_minor, op_type, correlation_id)
         VALUES (?, ?, ?, 'DEBIT', ?)`,
        [idempotencyKey, accountId, amountMinor, correlationId],
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
        [amountMinor, amountMinor, accountId, amountMinor],
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

## MongoDB: Projection

```typescript
import { MongoClient } from "mongodb";

export async function appendTransfer(
  mongo: MongoClient,
  customerId: string,
  transferId: string,
  amountMinor: number,
  currency: string,
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
    },
  );
}
```

## Notes

- Prefer **bigint** for money fields end-to-end; serialize carefully in JSON APIs.
- For serverless, pool externally (ProxySQL, RDS Proxy, Hyperdrive) or accept shorter connection lifetimes.
