# Kotlin / Java Interop for Ledger Code

## Strategy

- **Shared module**: implement `LedgerRepository` once in Java (see [`../java/JDBC_CLIENTS.md`](../java/JDBC_CLIENTS.md)) and depend on it from Kotlin Gradle source sets.
- **Ktor handlers**: keep controllers thin; call Java repository methods on **`Dispatchers.IO`** (or configured JDBC dispatcher).

## Example: Wrapping Java Repository

```kotlin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class LedgerFacade(private val javaLedger: LedgerRepository) {
    suspend fun debitIfAbsent(
        accountId: Long,
        amountMinor: Long,
        idempotencyKey: String,
        correlationId: String,
    ): Boolean = withContext(Dispatchers.IO) {
        javaLedger.debitIfAbsent(accountId, amountMinor, idempotencyKey, correlationId)
    }
}
```

## Roles

| Role | Notes |
| ---- | ----- |
| **Language Maintainer** | Documents null-safety at Java boundaries (`@Nullable` / `@NonNull`). |
| **SRE** | Ensures combined services do not double pool connections (one Hikari pool per process). |
