# Saga Pattern Implementation
## Choreography-Based Saga with Compensating Transactions

## Overview

The Saga pattern ensures data consistency across MySQL and MongoDB databases by orchestrating distributed transactions through a series of local transactions with compensating actions for rollback.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Service   │────▶│ Event Bus   │────▶│   Service   │
│     A       │     │  (Kafka)    │     │     B       │
└─────────────┘     └─────────────┘     └─────────────┘
     │                    │                    │
     ▼                    ▼                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   MySQL     │     │  Dead       │     │  MongoDB    │
│  (Tier 1)   │     │  Letter Q   │     │  (Tier 2)   │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Implementation

### Event Definitions

```javascript
// saga-events.js
const SagaEvents = {
  // Transfer Saga Events
  TRANSFER_INITIATED: "transfer.initiated",
  ACCOUNT_DEBITED: "account.debited",
  ACCOUNT_CREDITED: "account.credited",
  CUSTOMER_VIEW_UPDATED: "customer.view.updated",
  TRANSFER_COMPLETED: "transfer.completed",
  TRANSFER_FAILED: "transfer.failed",
  
  // Payment Saga Events
  PAYMENT_INITIATED: "payment.initiated",
  PAYMENT_PROCESSED: "payment.processed",
  MERCHANT_NOTIFIED: "merchant.notified",
  PAYMENT_COMPLETED: "payment.completed",
  PAYMENT_FAILED: "payment.failed"
};

module.exports = SagaEvents;
```

### Saga Orchestrator

```javascript
// saga-orchestrator.js
const mysql = require('./mysql-client');
const mongodb = require('./mongodb-client');
const eventBus = require('./event-bus');
const SagaEvents = require('./saga-events');
const { generateIdempotencyKey, storeSagaState, getSagaState } = require('./saga-storage');

class TransferSaga {
  constructor() {
    this.compensators = new Map();
    this.setupCompensators();
  }
  
  setupCompensators() {
    // Compensating transaction for account debit
    this.compensators.set(SagaEvents.ACCOUNT_DEBITED, async (event) => {
      console.log(`Compensating: Rolling back debit for account ${event.from_account_id}`);
      await mysql.query(
        `UPDATE accounts 
         SET balance = balance + ?, 
             available_balance = available_balance + ?
         WHERE account_id = ?`,
        [event.amount, event.amount, event.from_account_id]
      );
      
      // Log compensation
      await mysql.query(
        `INSERT INTO saga_compensations 
         (saga_id, event_type, compensated_at, details) 
         VALUES (?, ?, NOW(), ?)`,
        [event.saga_id, SagaEvents.ACCOUNT_DEBITED, JSON.stringify(event)]
      );
    });
    
    // Compensating transaction for account credit
    this.compensators.set(SagaEvents.ACCOUNT_CREDITED, async (event) => {
      console.log(`Compensating: Rolling back credit for account ${event.to_account_id}`);
      await mysql.query(
        `UPDATE accounts 
         SET balance = balance - ?, 
             available_balance = available_balance - ?
         WHERE account_id = ?`,
        [event.amount, event.amount, event.to_account_id]
      );
      
      await mysql.query(
        `INSERT INTO saga_compensations 
         (saga_id, event_type, compensated_at, details) 
         VALUES (?, ?, NOW(), ?)`,
        [event.saga_id, SagaEvents.ACCOUNT_CREDITED, JSON.stringify(event)]
      );
    });
    
    // Compensating transaction for customer view update
    this.compensators.set(SagaEvents.CUSTOMER_VIEW_UPDATED, async (event) => {
      console.log(`Compensating: Rolling back customer view update for customer ${event.customer_id}`);
      await mongodb.collection('customers').updateOne(
        { customer_id: event.customer_id },
        {
          $inc: {
            'transactions.last_30_days_count': -1,
            'accounts.$[account].balance': -event.amount
          }
        },
        {
          arrayFilters: [{ 'account.account_id': event.account_id }]
        }
      );
    });
  }
  
  async execute(transferRequest) {
    const sagaId = generateIdempotencyKey();
    const sagaState = {
      saga_id: sagaId,
      type: 'TRANSFER',
      status: 'IN_PROGRESS',
      steps: [],
      started_at: new Date(),
      transfer_request: transferRequest
    };
    
    try {
      // Store initial saga state
      await storeSagaState(sagaState);
      
      // Step 1: Debit source account (MySQL)
      console.log(`[Saga ${sagaId}] Step 1: Debiting account ${transferRequest.from_account_id}`);
      const debitResult = await this.debitAccount(
        transferRequest.from_account_id,
        transferRequest.amount,
        sagaId
      );
      
      sagaState.steps.push({
        step: 1,
        event: SagaEvents.ACCOUNT_DEBITED,
        completed_at: new Date(),
        result: debitResult
      });
      await storeSagaState(sagaState);
      
      // Publish event
      await eventBus.publish(SagaEvents.ACCOUNT_DEBITED, {
        saga_id: sagaId,
        account_id: transferRequest.from_account_id,
        amount: transferRequest.amount,
        ...transferRequest
      });
      
      // Step 2: Credit destination account (MySQL)
      console.log(`[Saga ${sagaId}] Step 2: Crediting account ${transferRequest.to_account_id}`);
      const creditResult = await this.creditAccount(
        transferRequest.to_account_id,
        transferRequest.amount,
        sagaId
      );
      
      sagaState.steps.push({
        step: 2,
        event: SagaEvents.ACCOUNT_CREDITED,
        completed_at: new Date(),
        result: creditResult
      });
      await storeSagaState(sagaState);
      
      await eventBus.publish(SagaEvents.ACCOUNT_CREDITED, {
        saga_id: sagaId,
        account_id: transferRequest.to_account_id,
        amount: transferRequest.amount,
        ...transferRequest
      });
      
      // Step 3: Update customer view (MongoDB)
      console.log(`[Saga ${sagaId}] Step 3: Updating customer view for ${transferRequest.customer_id}`);
      const viewUpdateResult = await this.updateCustomerView(
        transferRequest.customer_id,
        transferRequest,
        sagaId
      );
      
      sagaState.steps.push({
        step: 3,
        event: SagaEvents.CUSTOMER_VIEW_UPDATED,
        completed_at: new Date(),
        result: viewUpdateResult
      });
      await storeSagaState(sagaState);
      
      await eventBus.publish(SagaEvents.CUSTOMER_VIEW_UPDATED, {
        saga_id: sagaId,
        customer_id: transferRequest.customer_id,
        ...transferRequest
      });
      
      // Mark saga as completed
      sagaState.status = 'COMPLETED';
      sagaState.completed_at = new Date();
      await storeSagaState(sagaState);
      
      await eventBus.publish(SagaEvents.TRANSFER_COMPLETED, {
        saga_id: sagaId,
        ...transferRequest
      });
      
      console.log(`[Saga ${sagaId}] Transfer completed successfully`);
      return { success: true, saga_id: sagaId };
      
    } catch (error) {
      console.error(`[Saga ${sagaId}] Error occurred:`, error);
      
      // Compensate all completed steps
      await this.compensate(sagaId, sagaState.steps);
      
      sagaState.status = 'FAILED';
      sagaState.failed_at = new Date();
      sagaState.error = error.message;
      await storeSagaState(sagaState);
      
      await eventBus.publish(SagaEvents.TRANSFER_FAILED, {
        saga_id: sagaId,
        error: error.message,
        ...transferRequest
      });
      
      throw error;
    }
  }
  
  async debitAccount(accountId, amount, sagaId) {
    // Check idempotency
    const existingTransaction = await mysql.query(
      `SELECT * FROM saga_transactions 
       WHERE saga_id = ? AND event_type = ?`,
      [sagaId, SagaEvents.ACCOUNT_DEBITED]
    );
    
    if (existingTransaction.length > 0) {
      console.log(`[Saga ${sagaId}] Debit already processed, skipping`);
      return existingTransaction[0];
    }
    
    // Execute debit
    const result = await mysql.query(
      `UPDATE accounts 
       SET balance = balance - ?, 
           available_balance = available_balance - ?,
           updated_at = NOW()
       WHERE account_id = ? AND available_balance >= ?`,
      [amount, amount, accountId, amount]
    );
    
    if (result.affectedRows === 0) {
      throw new Error(`Insufficient balance for account ${accountId}`);
    }
    
    // Record saga transaction
    await mysql.query(
      `INSERT INTO saga_transactions 
       (saga_id, event_type, account_id, amount, created_at) 
       VALUES (?, ?, ?, ?, NOW())`,
      [sagaId, SagaEvents.ACCOUNT_DEBITED, accountId, amount]
    );
    
    return { account_id: accountId, amount, status: 'DEBITED' };
  }
  
  async creditAccount(accountId, amount, sagaId) {
    // Check idempotency
    const existingTransaction = await mysql.query(
      `SELECT * FROM saga_transactions 
       WHERE saga_id = ? AND event_type = ?`,
      [sagaId, SagaEvents.ACCOUNT_CREDITED]
    );
    
    if (existingTransaction.length > 0) {
      console.log(`[Saga ${sagaId}] Credit already processed, skipping`);
      return existingTransaction[0];
    }
    
    // Execute credit
    await mysql.query(
      `UPDATE accounts 
       SET balance = balance + ?, 
           available_balance = available_balance + ?,
           updated_at = NOW()
       WHERE account_id = ?`,
      [amount, amount, accountId]
    );
    
    // Record saga transaction
    await mysql.query(
      `INSERT INTO saga_transactions 
       (saga_id, event_type, account_id, amount, created_at) 
       VALUES (?, ?, ?, ?, NOW())`,
      [sagaId, SagaEvents.ACCOUNT_CREDITED, accountId, amount]
    );
    
    return { account_id: accountId, amount, status: 'CREDITED' };
  }
  
  async updateCustomerView(customerId, transferRequest, sagaId) {
    // Check idempotency
    const existingUpdate = await mongodb.collection('saga_updates').findOne({
      saga_id: sagaId,
      event_type: SagaEvents.CUSTOMER_VIEW_UPDATED
    });
    
    if (existingUpdate) {
      console.log(`[Saga ${sagaId}] Customer view update already processed, skipping`);
      return existingUpdate;
    }
    
    // Update customer view
    await mongodb.collection('customers').updateOne(
      { customer_id: customerId },
      {
        $inc: {
          'transactions.last_30_days_count': 1,
          'accounts.$[account].balance': transferRequest.amount
        },
        $set: {
          'transactions.last_transaction_date': new Date(),
          'updated_at': new Date()
        }
      },
      {
        arrayFilters: [{ 'account.account_id': transferRequest.to_account_id }]
      }
    );
    
    // Record saga update
    await mongodb.collection('saga_updates').insertOne({
      saga_id: sagaId,
      event_type: SagaEvents.CUSTOMER_VIEW_UPDATED,
      customer_id: customerId,
      created_at: new Date()
    });
    
    return { customer_id: customerId, status: 'UPDATED' };
  }
  
  async compensate(sagaId, completedSteps) {
    console.log(`[Saga ${sagaId}] Starting compensation for ${completedSteps.length} steps`);
    
    // Compensate in reverse order
    for (let i = completedSteps.length - 1; i >= 0; i--) {
      const step = completedSteps[i];
      const compensator = this.compensators.get(step.event);
      
      if (compensator) {
        try {
          console.log(`[Saga ${sagaId}] Compensating step ${step.step}: ${step.event}`);
          await compensator({
            saga_id: sagaId,
            ...step.result
          });
        } catch (error) {
          console.error(`[Saga ${sagaId}] Compensation failed for step ${step.step}:`, error);
          // Continue with other compensations even if one fails
        }
      }
    }
    
    console.log(`[Saga ${sagaId}] Compensation completed`);
  }
}

module.exports = TransferSaga;
```

### Dead Letter Queue Handler

```javascript
// dead-letter-queue.js
const eventBus = require('./event-bus');
const mysql = require('./mysql-client');
const mongodb = require('./mongodb-client');

class DeadLetterQueue {
  constructor() {
    this.maxRetries = 5;
    this.baseBackoffMs = 1000;
    this.maxBackoffMs = 30000;
  }
  
  async handleFailedEvent(event, error, retryCount = 0) {
    const eventId = event.event_id || generateId();
    
    console.log(`[DLQ] Handling failed event ${eventId}, retry ${retryCount}/${this.maxRetries}`);
    
    if (retryCount >= this.maxRetries) {
      // Store in dead letter queue
      await this.storeInDLQ(event, error, retryCount);
      
      // Alert operations team
      await this.alertOperations(event, error);
      
      return;
    }
    
    // Calculate exponential backoff
    const backoffMs = Math.min(
      this.baseBackoffMs * Math.pow(2, retryCount),
      this.maxBackoffMs
    );
    
    console.log(`[DLQ] Retrying event ${eventId} after ${backoffMs}ms`);
    
    // Schedule retry
    setTimeout(async () => {
      try {
        await this.retryEvent(event);
        console.log(`[DLQ] Event ${eventId} retried successfully`);
      } catch (retryError) {
        console.error(`[DLQ] Retry failed for event ${eventId}:`, retryError);
        await this.handleFailedEvent(event, retryError, retryCount + 1);
      }
    }, backoffMs);
  }
  
  async storeInDLQ(event, error, retryCount) {
    await mongodb.collection('dead_letter_queue').insertOne({
      event_id: event.event_id || generateId(),
      event_type: event.type,
      event_data: event,
      error: {
        message: error.message,
        stack: error.stack,
        name: error.name
      },
      retry_count: retryCount,
      first_failed_at: event.first_failed_at || new Date(),
      stored_at: new Date(),
      status: 'FAILED'
    });
    
    console.log(`[DLQ] Event stored in DLQ: ${event.event_id}`);
  }
  
  async alertOperations(event, error) {
    // Send alert via PagerDuty, Slack, etc.
    const alert = {
      severity: 'critical',
      title: `Saga Event Failed: ${event.type}`,
      message: `Event ${event.event_id} failed after ${this.maxRetries} retries`,
      error: error.message,
      event: event
    };
    
    // Implement alerting logic (PagerDuty, Slack, etc.)
    console.error('[DLQ] Alerting operations:', alert);
  }
  
  async retryEvent(event) {
    // Republish event to event bus
    await eventBus.publish(event.type, event);
  }
}

module.exports = DeadLetterQueue;
```

### Saga Storage Schema

```sql
-- saga_states.sql
CREATE TABLE saga_states (
  saga_id VARCHAR(100) PRIMARY KEY,
  saga_type VARCHAR(50) NOT NULL,
  status ENUM('IN_PROGRESS', 'COMPLETED', 'FAILED', 'COMPENSATED') NOT NULL,
  saga_data JSON NOT NULL,
  steps JSON NOT NULL,
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP NULL,
  failed_at TIMESTAMP NULL,
  error_message TEXT NULL,
  INDEX idx_status (status),
  INDEX idx_started_at (started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE saga_transactions (
  transaction_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  saga_id VARCHAR(100) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  account_id BIGINT UNSIGNED NULL,
  amount DECIMAL(20,2) NULL,
  details JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_saga_id (saga_id),
  INDEX idx_event_type (event_type),
  UNIQUE KEY uk_saga_event (saga_id, event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE saga_compensations (
  compensation_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  saga_id VARCHAR(100) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  details JSON NOT NULL,
  compensated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_saga_id (saga_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Usage Example

```javascript
// transfer-service.js
const TransferSaga = require('./saga-orchestrator');

async function processTransfer(transferRequest) {
  const saga = new TransferSaga();
  
  try {
    const result = await saga.execute({
      from_account_id: transferRequest.fromAccountId,
      to_account_id: transferRequest.toAccountId,
      customer_id: transferRequest.customerId,
      amount: transferRequest.amount,
      description: transferRequest.description
    });
    
    return {
      success: true,
      saga_id: result.saga_id,
      message: 'Transfer completed successfully'
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      message: 'Transfer failed and has been compensated'
    };
  }
}

module.exports = { processTransfer };
```

## Monitoring

### Key Metrics

- Saga completion rate
- Saga failure rate
- Average saga duration
- Compensation execution time
- Dead letter queue size
- Retry success rate

### Alerts

- Saga failure rate > 1%
- Saga duration > 30 seconds
- Dead letter queue size > 100
- Compensation failures

## Best Practices

1. **Idempotency**: All saga steps must be idempotent
2. **Compensation**: Always implement compensating transactions
3. **Monitoring**: Track all saga states and transitions
4. **Retry Logic**: Implement exponential backoff for retries
5. **Dead Letter Queue**: Store failed events for manual intervention
6. **Timeouts**: Set appropriate timeouts for each step
7. **Logging**: Log all saga events for debugging
