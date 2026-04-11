# Python: PyMySQL + pymongo

## MySQL: Idempotent Debit

```python
from contextlib import contextmanager
import pymysql

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

## MongoDB: Projection

```python
from datetime import datetime, timezone

def append_transfer(db, customer_id: str, transfer_id: str, amount_minor: int, currency: str) -> None:
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

## Notes

- For high concurrency, prefer a **connection pool** (`DBUtils.PooledDB` or SQLAlchemy pool) instead of opening a connection per request.
- Use **Motor** for async FastAPI handlers if the service is asyncio-native.
