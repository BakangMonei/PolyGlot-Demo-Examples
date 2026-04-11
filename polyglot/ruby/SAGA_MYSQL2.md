# Ruby: mysql2 Idempotent Debit

```ruby
require "mysql2"

class LedgerRepository
  def initialize(pool)
    @pool = pool
  end

  # @return [Boolean] true if applied
  def debit_if_absent(account_id:, amount_minor:, idempotency_key:, correlation_id:)
    @pool.with do |conn|
      conn.query("BEGIN")
      ins = conn.prepare(
        <<~SQL
          INSERT IGNORE INTO ledger_operations
            (idempotency_key, account_id, amount_minor, op_type, correlation_id)
          VALUES (?, ?, ?, 'DEBIT', ?)
        SQL
      )
      ins.execute(idempotency_key, account_id, amount_minor, correlation_id)
      if conn.affected_rows == 0
        conn.query("ROLLBACK")
        return false
      end

      upd = conn.prepare(
        <<~SQL
          UPDATE accounts
          SET balance = balance - ?,
              available_balance = available_balance - ?
          WHERE account_id = ?
            AND available_balance >= ?
        SQL
      )
      upd.execute(amount_minor, amount_minor, account_id, amount_minor)
      if conn.affected_rows != 1
        conn.query("ROLLBACK")
        raise "insufficient funds or missing account"
      end

      conn.query("COMMIT")
      true
    end
  end
end
```

## MongoDB

Use the **`mongo`** or official driver gem set approved by your security team; persist resume tokens for change streams in the same way as other languages.
