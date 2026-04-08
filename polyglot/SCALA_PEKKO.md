# Scala 3 + Pekko HTTP + JDBC / Slick

Scala services often sit next to JVM-based cores. This example uses **Pekko HTTP** (Apache Pekko) and plain **JDBC** for clarity; Slick or Doobie can replace the JDBC block without changing HTTP semantics.

## build.sbt (Illustrative)

```scala
val pekkover = "1.0.2"
libraryDependencies ++= Seq(
  "org.apache.pekko" %% "pekko-http" % pekkover,
  "org.apache.pekko" %% "pekko-stream" % pekkover,
  "com.mysql" % "mysql-connector-j" % "8.3.0"
)
```

## Debit Route + Repository

```scala
import org.apache.pekko.actor.typed.ActorSystem
import org.apache.pekko.http.scaladsl.server.Directives.*
import org.apache.pekko.http.scaladsl.server.Route

import java.sql.DriverManager
import scala.concurrent.{ExecutionContext, Future}

final class LedgerRepo(jdbcUrl: String, user: String, password: String)(using ExecutionContext):

  def debitIfAbsent(
      accountId: Long,
      amountMinor: Long,
      idempotencyKey: String,
      correlationId: String
  ): Future[Boolean] = Future:
    val conn = DriverManager.getConnection(jdbcUrl, user, password)
    try
      conn.setAutoCommit(false)
      val ins = conn.prepareStatement(
        """INSERT IGNORE INTO ledger_operations
             (idempotency_key, account_id, amount_minor, op_type, correlation_id)
           VALUES (?, ?, ?, 'DEBIT', ?)"""
      )
      try
        ins.setString(1, idempotencyKey)
        ins.setLong(2, accountId)
        ins.setLong(3, amountMinor)
        ins.setString(4, correlationId)
        if ins.executeUpdate() == 0 then
          conn.rollback()
          false
        else
          val upd = conn.prepareStatement(
            """UPDATE accounts
                 SET balance = balance - ?,
                     available_balance = available_balance - ?
               WHERE account_id = ?
                 AND available_balance >= ?"""
          )
          try
            upd.setLong(1, amountMinor)
            upd.setLong(2, amountMinor)
            upd.setLong(3, accountId)
            upd.setLong(4, amountMinor)
            if upd.executeUpdate() != 1 then
              conn.rollback()
              throw new IllegalStateException("Insufficient funds or missing account")
            conn.commit()
            true
          finally upd.close()
      finally ins.close()
    finally conn.close()

end LedgerRepo

object Routes:
  def apply(repo: LedgerRepo)(using ActorSystem[?], ExecutionContext): Route =
    (post & path("debit" / Segment)) { idempotencyKey =>
      entity(as[String]) { body =>
        // Parse JSON with circe/jsoniter in real services
        complete(repo.debitIfAbsent(1L, 1L, idempotencyKey, "corr"))
      }
    }
```

## MongoDB Engagement

Use the **MongoDB Java Driver** from Scala (it is often simpler than wrapping a Scala-native driver for advanced features like change streams). Alternatively, **mongo-scala-driver** if your security reviews approve the stack.

```scala
import com.mongodb.client.model.Filters
import com.mongodb.client.model.Updates
import org.bson.Document

def appendTransfer(coll: com.mongodb.client.MongoCollection[Document], customerId: String): Unit =
  coll.updateOne(
    Filters.eq("customer_id", customerId),
    Updates.combine(
      Updates.push(
        "recent_transfers",
        new Document("transfer_id", "t-1").append("amount_minor", java.lang.Long.valueOf(100))
      ),
      Updates.set("last_updated_at", java.time.Instant.now().toString)
    )
  )
```

## Notes

- Prefer **`blocking`** execution contexts for JDBC under Pekko HTTP unless you adopt a fully non-blocking database client.
- Align JSON error models with your API gateway standards documented in `security/SECURITY_CONFIG.md`.
