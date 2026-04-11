# Go: database/sql + mongo-go-driver

## MySQL: Idempotent Debit

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

The deferred `Rollback` runs after `Commit`; on success it usually yields `sql.ErrTxDone`, ignored with `_`.

## MongoDB: Engagement Projection

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

## Operational Notes

- Wrap every outbound call with `context.WithTimeout` for OLTP paths; see [`../shared/RESILIENCE_AND_POOLING.md`](../shared/RESILIENCE_AND_POOLING.md).
- For change streams, persist the **resume token** before publishing downstream events.
