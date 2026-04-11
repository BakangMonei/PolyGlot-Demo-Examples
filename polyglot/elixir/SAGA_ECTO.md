# Elixir: Ecto + MyXQL Idempotent Debit

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

> `LedgerOperation` must map to `ledger_operations` with a unique index on `idempotency_key`. Adjust `on_conflict` for your Ecto/MySQL version.

## MongoDB

Use **`mongodb`** Elixir driver under supervision; connect read-model updates to the same outbox rules as other runtimes.
