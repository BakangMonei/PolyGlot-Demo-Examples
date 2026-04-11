# Java

Guides for JVM services integrating **MySQL (SoR)** and **MongoDB (SoE)** with the same saga and idempotency contracts as the rest of this repository.

## Contents

| Doc                                      | Description                                                          |
| ---------------------------------------- | -------------------------------------------------------------------- |
| [JDBC_CLIENTS.md](./JDBC_CLIENTS.md)     | HikariCP, JDBC idempotent debit, MongoDB sync driver, Spring outline |
| [R2DBC_REACTIVE.md](./R2DBC_REACTIVE.md) | WebFlux-style R2DBC + reactive Mongo projections                     |
| [GRPC_SERVICE.md](./GRPC_SERVICE.md)     | gRPC `LedgerService` server binding the JDBC repository              |

## Roles (this folder)

| Role                    | Responsibility                                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Language Maintainer** | Keeps Hikari / driver properties and Spring samples aligned with supported LTS JDKs.                                            |
| **Security Reviewer**   | Confirms no secrets in samples; validates TLS and vault integration patterns for JDBC URLs.                                     |
| **SRE**                 | Confirms pool sizing and OTel JDBC guidance match [`../shared/RESILIENCE_AND_POOLING.md`](../shared/RESILIENCE_AND_POOLING.md). |

Global role definitions: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
- [`../../patterns/SAGA_PATTERN.md`](../../patterns/SAGA_PATTERN.md)
