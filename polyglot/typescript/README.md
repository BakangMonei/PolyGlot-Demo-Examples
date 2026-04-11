# TypeScript / Node.js

Shared types across BFFs and browser-adjacent tooling. Split between **plain Node** drivers and **NestJS** structure for larger services.

## Contents

| Doc                                    | Description                                 |
| -------------------------------------- | ------------------------------------------- |
| [MYSQL_MONGODB.md](./MYSQL_MONGODB.md) | `mysql2/promise` + `mongodb` driver samples |
| [NESTJS.md](./NESTJS.md)               | Modules, guards, DI for ledger + engagement |

## Roles (this folder)

| Role                    | Responsibility                                                                   |
| ----------------------- | -------------------------------------------------------------------------------- |
| **Language Maintainer** | Pins `mysql2` / `mongodb` major versions; documents ESM vs CJS for each service. |
| **Security Reviewer**   | npm audit policy, supply-chain review for native addons.                         |
| **API Owner**           | Aligns OpenAPI and gRPC gateway mapping if both exist.                           |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)
