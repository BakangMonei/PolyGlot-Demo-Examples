# Polyglot Saga Step Reference

This file shows the **same logical step**—record idempotent intent in MySQL, mutate balance if funds allow—in multiple languages. It is intentionally smaller than full orchestrators in `patterns/SAGA_PATTERN.md` so you can copy patterns into services written in different runtimes.

## Shared Preconditions

- Table `ledger_operations.idempotency_key` is **UNIQUE**.
- `INSERT IGNORE` (MySQL) or equivalent deduplication strategy is acceptable for “at most once debit registration”.
- MongoDB updates belong **after** durable commit or via **outbox** relay (recommended for production).

---

## Java (JDBC)

See full class in [JAVA.md](./JAVA.md) (`LedgerRepository.debitIfAbsent`).

---

## Rust (`sqlx`)

See [RUST.md](./RUST.md) (`Ledger::debit_if_absent`).

---

## C# (`MySqlConnector`)

See [CSHARP.md](./CSHARP.md) (`LedgerRepository.DebitIfAbsentAsync`).

---

## Go

See [OTHER_LANGUAGES.md](./OTHER_LANGUAGES.md) (`ledger.Repository.DebitIfAbsent`).

---

## Python

See [OTHER_LANGUAGES.md](./OTHER_LANGUAGES.md) (`LedgerRepository.debit_if_absent`).

---

## TypeScript

See [OTHER_LANGUAGES.md](./OTHER_LANGUAGES.md) (`LedgerRepository.debitIfAbsent`).

---

## Kotlin (Exposed)

See [OTHER_LANGUAGES.md](./OTHER_LANGUAGES.md) (`LedgerRepository.debitIfAbsent`).

---

## PHP (PDO) — Bonus

```php
<?php
declare(strict_types=1);

final class LedgerRepository
{
    public function __construct(private PDO $pdo) {}

    public function debitIfAbsent(
        int $accountId,
        int $amountMinor,
        string $idempotencyKey,
        string $correlationId
    ): bool {
        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare(
                'INSERT IGNORE INTO ledger_operations
                   (idempotency_key, account_id, amount_minor, op_type, correlation_id)
                 VALUES (:k, :a, :m, \'DEBIT\', :c)'
            );
            $stmt->execute([
                ':k' => $idempotencyKey,
                ':a' => $accountId,
                ':m' => $amountMinor,
                ':c' => $correlationId,
            ]);
            if ($stmt->rowCount() === 0) {
                $this->pdo->rollBack();
                return false;
            }

            $upd = $this->pdo->prepare(
                'UPDATE accounts
                 SET balance = balance - :m,
                     available_balance = available_balance - :m2
                 WHERE account_id = :a
                   AND available_balance >= :m3'
            );
            $upd->execute([
                ':m' => $amountMinor,
                ':m2' => $amountMinor,
                ':a' => $accountId,
                ':m3' => $amountMinor,
            ]);
            if ($upd->rowCount() !== 1) {
                $this->pdo->rollBack();
                throw new RuntimeException('Insufficient funds or missing account');
            }

            $this->pdo->commit();
            return true;
        } catch (Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }
    }
}
```

---

## Ruby (`mysql2` gem) — Bonus

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

---

## Elixir (`Ecto` + MyXQL) — Bonus

```elixir
defmodule Banking.Ledger do
  import Ecto.Query
  alias Banking.Repo
  alias Banking.LedgerOperation
  alias Banking.Account

  def debit_if_absent(account_id, amount_minor, idempotency_key, correlation_id) do
    Repo.transaction(fn ->
      {inserted, _} =
        Repo.insert_all(
          LedgerOperation,
          [
            %{
              idempotency_key: idempotency_key,
              account_id: account_id,
              amount_minor: amount_minor,
              op_type: "DEBIT",
              correlation_id: correlation_id
            }
          ],
          on_conflict: :nothing,
          conflict_target: [:idempotency_key]
        )

      if inserted == 0 do
        Repo.rollback(:duplicate)
      end

      res =
        from(a in Account,
          where: a.id == ^account_id and a.available_balance >= ^amount_minor,
          update: [
            set: [
              balance: a.balance - ^amount_minor,
              available_balance: a.available_balance - ^amount_minor
            ]
          ]
        )
        |> Repo.update_all([])

      case res do
        {1, _} -> :ok
        _ -> Repo.rollback(:insufficient_funds)
      end

      true
    end)
    |> case do
      {:ok, true} -> {:ok, true}
      {:error, :duplicate} -> {:ok, false}
      other -> other
    end
  end
end
```

> The `LedgerOperation` schema must map to `ledger_operations` with a unique index on `idempotency_key`. Adjust `on_conflict` options for your Ecto/MySQL version.
