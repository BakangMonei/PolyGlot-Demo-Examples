# Kotlin: JDBC + `use` Blocks

```kotlin
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

## MongoDB

Reuse the **MongoDB Java Driver** from Kotlin (`org.mongodb:mongodb-driver-sync`) with the same BSON APIs as the Java guide, or use **KMongo** if approved by security review.
