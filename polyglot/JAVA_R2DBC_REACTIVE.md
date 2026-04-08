# Java Reactive Stack (R2DBC + Reactive MongoDB)

Use when gateways require **non-blocking end-to-end** threads (WebFlux, virtual-thread hybrids, or high fan-out I/O).

## Maven Coordinates (Illustrative)

```xml
<dependency>
  <groupId>io.r2dbc</groupId>
  <artifactId>r2dbc-pool</artifactId>
</dependency>
<dependency>
  <groupId>org.postgresql</groupId>
  <artifactId>r2dbc-postgresql</artifactId>
</dependency>
```

> For **MySQL**, use `io.asyncer:r2dbc-mysql` or vendor-specific R2DBC drivers aligned with your supported database versions.

## R2DBC Idempotent Debit (Transactional Operator)

```java
import io.r2dbc.spi.Connection;
import io.r2dbc.spi.ConnectionFactory;
import org.springframework.r2dbc.core.DatabaseClient;
import org.springframework.transaction.reactive.TransactionalOperator;
import reactor.core.publisher.Mono;

public class ReactiveLedgerRepository {
  private final DatabaseClient db;
  private final TransactionalOperator tx;

  public ReactiveLedgerRepository(DatabaseClient db, TransactionalOperator tx) {
    this.db = db;
    this.tx = tx;
  }

  public Mono<Boolean> debitIfAbsent(
      long accountId, long amountMinor, String idempotencyKey, String correlationId) {

    Mono<Boolean> work =
        db.sql(
                """
                INSERT IGNORE INTO ledger_operations
                  (idempotency_key, account_id, amount_minor, op_type, correlation_id)
                VALUES (:k, :a, :m, 'DEBIT', :c)
                """)
            .bind("k", idempotencyKey)
            .bind("a", accountId)
            .bind("m", amountMinor)
            .bind("c", correlationId)
            .fetch()
            .rowsUpdated()
            .flatMap(
                inserted -> {
                  if (inserted == 0) return Mono.just(false);

                  return db.sql(
                          """
                          UPDATE accounts
                          SET balance = balance - :m,
                              available_balance = available_balance - :m
                          WHERE account_id = :a
                            AND available_balance >= :m
                          """)
                      .bind("m", amountMinor)
                      .bind("a", accountId)
                      .fetch()
                      .rowsUpdated()
                      .flatMap(
                          updated -> {
                            if (updated != 1) {
                              return Mono.error(
                                  new IllegalStateException("Insufficient funds or missing account"));
                            }
                            return Mono.just(true);
                          });
                });

    return tx.transactional(work);
  }
}
```

## Reactive MongoDB Projection

```java
import com.mongodb.reactivestreams.client.MongoCollection;
import org.bson.Document;
import reactor.core.publisher.Mono;

public class ReactiveCustomer360Repository {
  private final MongoCollection<Document> customers;

  public Mono<Void> appendTransfer(
      String customerId, String transferId, long amountMinor, String currency) {
    Document snippet =
        new Document("transfer_id", transferId)
            .append("amount_minor", amountMinor)
            .append("currency", currency)
            .append("occurred_at", java.time.Instant.now().toString());

    return Mono.from(
            customers.updateOne(
                new Document("customer_id", customerId),
                new Document(
                    "$push", new Document("recent_transfers", snippet))
                    .append("$set", new Document("last_updated_at", java.time.Instant.now().toString()))))
        .then();
  }
}
```

## Guidance

- Keep **saga orchestration** state in MySQL or a durable log; reactive pipelines should not rely on in-memory-only saga graphs.
- Prefer **bounded concurrency** (`flatMap(..., 32)`) when fanning out to MongoDB to avoid overload during incident traffic spikes.
