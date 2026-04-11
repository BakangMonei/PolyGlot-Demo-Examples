# PHP: PDO Idempotent Debit

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

## MongoDB

Use the official **`mongodb`** PHP extension with BSON documents for engagement projections; keep write ordering consistent with saga documentation.
