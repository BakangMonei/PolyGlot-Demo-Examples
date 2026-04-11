# Messaging Layer (Apache Kafka)

## Topics (production targets)

| Topic | Partitions (prod) | RF | Min ISR | Retention |
| ----- | ----------------- | -- | ------- | --------- |
| `transactions.created` | 24 | 3 | 2 | 7d / 100GB cap |
| `accounts.updated` | 12 | 3 | 2 | 7d |
| `audit.events` | 12 | 3 | 2 | 7d |
| `fraud.alerts` | 24 | 3 | 2 | 7d |
| `fraud.alerts.DLQ` | 6 | 3 | 2 | 14d |

Local `docker-compose` uses RF=1 and auto-create topics.

## Dead-letter queue (DLQ)

Consumers **must** catch poison messages, emit metadata to `fraud.alerts.DLQ` (or per-domain DLQ), and commit offsets only after durable DLQ write. See `patterns/SAGA_PATTERN.md` for saga alignment.

## Producers (reference)

- [producers/typescript](./producers/typescript/)
- [producers/python](./producers/python/)
- [producers/go](./producers/go/)

## Consumers (reference)

Java (Spring), Kotlin, and Scala consumer patterns are documented in:

- `polyglot/java/account-service/README.md` (Kafka listener extension)
- `polyglot/kotlin/account-service/README.md`
- `polyglot/scala/account-service/README.md`
