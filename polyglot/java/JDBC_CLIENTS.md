# Java: JDBC, HikariCP, MongoDB Driver

## Stack Options

| Layer | Common choices |
| ----- | -------------- |
| MySQL | JDBC + **HikariCP**, jOOQ, Spring Data JDBC, Hibernate |
| MongoDB | **MongoDB Java Driver** (sync or reactive), Spring Data MongoDB |
| Async | Virtual threads (Java 21+), Project Reactor, JDK `HttpClient` |

## HikariCP + JDBC (System of Record)

```java
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

public final class MysqlLedgerDataSource {

  public static DataSource create() {
    HikariConfig cfg = new HikariConfig();
    cfg.setJdbcUrl(System.getenv("MYSQL_JDBC_URL")); // e.g. jdbc:mysql://...
    cfg.setUsername(System.getenv("MYSQL_USER"));
    cfg.setPassword(System.getenv("MYSQL_PASSWORD"));
    cfg.setMaximumPoolSize(32);
    cfg.setMinimumIdle(8);
    cfg.addDataSourceProperty("cachePrepStmts", "true");
    cfg.addDataSourceProperty("prepStmtCacheSize", "250");
    cfg.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");
    cfg.setPoolName("banking-mysql");
    return new HikariDataSource(cfg);
  }
}

public final class LedgerRepository {
  private final DataSource ds;

  public LedgerRepository(DataSource ds) {
    this.ds = ds;
  }

  /**
   * Idempotent debit: if idempotency_key already exists, returns false without mutating balance.
   */
  public boolean debitIfAbsent(
      long accountId,
      long amountMinorUnits,
      String idempotencyKey,
      String correlationId) throws SQLException {

    final String insertOp =
        """
        INSERT IGNORE INTO ledger_operations
          (idempotency_key, account_id, amount_minor, op_type, correlation_id)
        VALUES (?, ?, ?, 'DEBIT', ?)
        """;

    final String applyDebit =
        """
        UPDATE accounts
        SET balance = balance - ?,
            available_balance = available_balance - ?
        WHERE account_id = ?
          AND available_balance >= ?
        """;

    try (Connection c = ds.getConnection()) {
      c.setAutoCommit(false);
      try (PreparedStatement ins = c.prepareStatement(insertOp);
          PreparedStatement upd = c.prepareStatement(applyDebit)) {

        ins.setString(1, idempotencyKey);
        ins.setLong(2, accountId);
        ins.setLong(3, amountMinorUnits);
        ins.setString(4, correlationId);

        try {
          int inserted = ins.executeUpdate(); // 0 if duplicate idempotency_key (UNIQUE + IGNORE)
          if (inserted == 0) {
            c.rollback();
            return false;
          }

          upd.setLong(1, amountMinorUnits);
          upd.setLong(2, amountMinorUnits);
          upd.setLong(3, accountId);
          upd.setLong(4, amountMinorUnits);

          int rows = upd.executeUpdate();
          if (rows != 1) {
            c.rollback();
            throw new IllegalStateException("Insufficient funds or missing account");
          }

          c.commit();
          return true;
        } catch (SQLException e) {
          c.rollback();
          throw e;
        }
      }
    }
  }
}
```

## MongoDB Java Driver (Customer 360 Projection)

```java
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.model.Filters;
import com.mongodb.client.model.Updates;
import org.bson.Document;
import org.bson.conversions.Bson;

import java.time.Instant;

public final class Customer360Repository {
  private final MongoCollection<Document> customers;

  public Customer360Repository(MongoClient client) {
    this.customers =
        client.getDatabase("banking_engagement").getCollection("customers");
  }

  public void appendTransferActivity(
      String customerId, String transferId, long amountMinor, String currency) {

    Bson filter = Filters.eq("customer_id", customerId);
    Bson push =
        Updates.push(
            "recent_transfers",
            new Document("transfer_id", transferId)
                .append("amount_minor", amountMinor)
                .append("currency", currency)
                .append("occurred_at", Instant.now().toString()));

    Bson touch = Updates.set("last_updated_at", Instant.now().toString());

    customers.updateOne(filter, Updates.combine(push, touch));
  }
}
```

## Spring Boot Style (Outline)

```java
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TransferCommandService {

  private final LedgerRepository ledger;
  private final Customer360Repository customer360;

  public TransferCommandService(LedgerRepository ledger, Customer360Repository customer360) {
    this.ledger = ledger;
    this.customer360 = customer360;
  }

  @Transactional // MySQL only; Mongo side-effect after commit via outbox or domain event
  public void initiateDebit(String idempotencyKey, long fromAccount, long amount, String correlationId)
      throws Exception {

    boolean applied = ledger.debitIfAbsent(fromAccount, amount, idempotencyKey, correlationId);
    if (!applied) {
      return; // idempotent no-op
    }

    // Prefer: write outbox row in same transaction, async relay updates MongoDB.
    // Direct call shown for clarity in prototypes only:
    // customer360.appendTransferActivity(...);
  }
}
```

## Observability

Wrap `DataSource` with OpenTelemetry instrumentation so JDBC spans inherit W3C trace context. Add span attribute `banking.correlation_id` from the command.

## Operational Notes

- Use **read/write split** at the pool level (separate Hikari pools for replicas) for reporting paths.
- For **change stream** consumers, prefer a dedicated microservice with backpressure and resume tokens persisted durably.
