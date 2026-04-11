# C# / .NET

High-throughput **MySqlConnector** and **MongoDB.Driver** patterns, plus optional **EF Core** for migration-heavy services.

## Contents

| Doc                                  | Description                                                                        |
| ------------------------------------ | ---------------------------------------------------------------------------------- |
| [ADONET.md](./ADONET.md)             | Async ADO.NET idempotent debit, Mongo repository, Minimal API host, change streams |
| [EF_CORE.md](./EF_CORE.md)           | EF Core models and execution strategy around the same saga step                    |
| [GRPC_SERVICE.md](./GRPC_SERVICE.md) | grpc-dotnet service implementation                                                 |

## Roles (this folder)

| Role                    | Responsibility                                                                   |
| ----------------------- | -------------------------------------------------------------------------------- |
| **Language Maintainer** | Keeps `MySqlConnector` vs `MySql.Data` guidance clear; tracks .NET LTS targets.  |
| **Security Reviewer**   | Validates connection string redaction and secret stores (Azure Key Vault, etc.). |
| **SRE**                 | Aligns Polly / OTel packages with platform standards.                            |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
