# NestJS: Modules, Guards, MySQL + Mongo

## Module Layout

```text
src/
  ledger/
    ledger.module.ts
    ledger.service.ts
    ledger.controller.ts
  engagement/
    engagement.module.ts
    engagement.service.ts
  common/
    idempotency.guard.ts
```

## Idempotency Guard

```typescript
import {
  CanActivate,
  ExecutionContext,
  Injectable,
  BadRequestException,
} from "@nestjs/common";
import { Request } from "express";

@Injectable()
export class IdempotencyGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const key = req.header("idempotency-key");
    if (!key || key.length < 8) {
      throw new BadRequestException("Idempotency-Key header required");
    }
    (req as { idempotencyKey?: string }).idempotencyKey = key;
    return true;
  }
}
```

## Ledger Service (mysql2 pool)

```typescript
import { Injectable } from "@nestjs/common";
import { Pool } from "mysql2/promise";

@Injectable()
export class LedgerService {
  constructor(private readonly pool: Pool) {}

  async debitIfAbsent(
    accountId: bigint,
    amountMinor: bigint,
    idempotencyKey: string,
    correlationId: string,
  ): Promise<boolean> {
    const conn = await this.pool.getConnection();
    try {
      await conn.beginTransaction();
      const [ins] = await conn.execute(
        `INSERT IGNORE INTO ledger_operations
           (idempotency_key, account_id, amount_minor, op_type, correlation_id)
         VALUES (?, ?, ?, 'DEBIT', ?)`,
        [idempotencyKey, accountId, amountMinor, correlationId],
      );
      const affectedInsert = (ins as import("mysql2").ResultSetHeader)
        .affectedRows;
      if (affectedInsert === 0) {
        await conn.rollback();
        return false;
      }

      const [upd] = await conn.execute(
        `UPDATE accounts
         SET balance = balance - ?,
             available_balance = available_balance - ?
         WHERE account_id = ?
           AND available_balance >= ?`,
        [amountMinor, amountMinor, accountId, amountMinor],
      );
      if ((upd as import("mysql2").ResultSetHeader).affectedRows !== 1) {
        await conn.rollback();
        throw new Error("Insufficient funds or missing account");
      }

      await conn.commit();
      return true;
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  }
}
```

## Engagement Service (mongoose connection)

```typescript
import { Injectable } from "@nestjs/common";
import { InjectConnection } from "@nestjs/mongoose";
import { Connection } from "mongoose";

@Injectable()
export class EngagementService {
  constructor(@InjectConnection() private readonly connection: Connection) {}

  async appendTransfer(
    customerId: string,
    transferId: string,
    amountMinor: number,
    currency: string,
  ) {
    const col = this.connection.collection("customers");
    await col.updateOne(
      { customer_id: customerId },
      {
        $push: {
          recent_transfers: {
            transfer_id: transferId,
            amount_minor: amountMinor,
            currency,
            occurred_at: new Date(),
          },
        },
        $set: { last_updated_at: new Date() },
      },
    );
  }
}
```

## Controller

```typescript
import { Body, Controller, Param, Post, UseGuards } from "@nestjs/common";
import { IdempotencyGuard } from "../common/idempotency.guard";
import { LedgerService } from "./ledger.service";

class DebitDto {
  accountId!: string;
  amountMinor!: string;
  correlationId!: string;
}

@Controller("ledger")
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Post("debit/:idempotencyKey")
  @UseGuards(IdempotencyGuard)
  async debit(
    @Param("idempotencyKey") idempotencyKey: string,
    @Body() body: DebitDto,
  ) {
    const applied = await this.ledger.debitIfAbsent(
      BigInt(body.accountId),
      BigInt(body.amountMinor),
      idempotencyKey,
      body.correlationId,
    );
    return { applied };
  }
}
```

> Production: prefer **outbox** after MySQL commit instead of calling MongoDB in the same HTTP request.

## Roles

| Role                    | Notes                                                    |
| ----------------------- | -------------------------------------------------------- |
| **Language Maintainer** | Aligns Nest major versions with Node LTS.                |
| **Security Reviewer**   | Validates authz on controllers and PII logging policies. |
