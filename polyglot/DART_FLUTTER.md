# Dart / Flutter Clients (Server or BFF)

Mobile and embedded banking surfaces often use **Dart**. For server-side access to MySQL and MongoDB, use `mysql_client` or `postgres`-style drivers where applicable; MongoDB has a first-party Dart driver for modern SDKs. Exact connection pool and `affectedRows` types vary by package version—validate against the driver you standardize on during security review.

## MySQL Idempotent Debit (`mysql_client` style)

```dart
import 'package:mysql_client/mysql_client.dart';

class LedgerRepository {
  LedgerRepository(this._pool);

  final MySQLConnectionPool _pool;

  Future<bool> debitIfAbsent({
    required int accountId,
    required int amountMinor,
    required String idempotencyKey,
    required String correlationId,
  }) async {
    final conn = await _pool.getConnection();
    try {
      await conn.execute('START TRANSACTION');

      final ins = await conn.execute(
        '''
        INSERT IGNORE INTO ledger_operations
          (idempotency_key, account_id, amount_minor, op_type, correlation_id)
        VALUES (:k, :a, :m, 'DEBIT', :c)
        ''',
        {'k': idempotencyKey, 'a': accountId, 'm': amountMinor, 'c': correlationId},
      );

      if (ins.affectedRows == BigInt.zero) {
        await conn.execute('ROLLBACK');
        return false;
      }

      final upd = await conn.execute(
        '''
        UPDATE accounts
        SET balance = balance - :m,
            available_balance = available_balance - :m2
        WHERE account_id = :a
          AND available_balance >= :m3
        ''',
        {'m': amountMinor, 'm2': amountMinor, 'a': accountId, 'm3': amountMinor},
      );

      if (upd.affectedRows != BigInt.one) {
        await conn.execute('ROLLBACK');
        throw StateError('Insufficient funds or missing account');
      }

      await conn.execute('COMMIT');
      return true;
    } catch (e) {
      await conn.execute('ROLLBACK');
      rethrow;
    } finally {
      await conn.close();
    }
  }
}
```

> Parameter binding names and `affectedRows` types vary by package; normalize on **one** supported driver per platform (VM vs WASM) during security review.

## MongoDB Projection (`mongo_dart` style)

```dart
import 'package:mongo_dart/mongo_dart.dart';

Future<void> appendTransfer(Db db, String customerId, String transferId, int amountMinor, String currency) async {
  final col = db.collection('customers');
  final modifier = ModifierBuilder()
    ..push('recent_transfers', {
      'transfer_id': transferId,
      'amount_minor': amountMinor,
      'currency': currency,
      'occurred_at': DateTime.now().toUtc(),
    })
    ..set('last_updated_at', DateTime.now().toUtc());

  await col.update(where.eq('customer_id', customerId), modifier);
}
```

## Architecture Fit

- Prefer **thin mobile clients** calling a BFF; do not embed privileged DSN credentials in Flutter assets.
- For offline-first UX, queue commands locally and reconcile with **idempotency keys** generated on device but validated server-side.
