# CQRS Pattern Implementation
## Command Query Responsibility Segregation with Eventual Consistency

## Overview

CQRS separates the command model (MySQL - writes) from the query model (MongoDB - reads), enabling optimized read and write patterns while maintaining eventual consistency through event projection.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Command    │────▶│   Event     │────▶│   Query     │
│   Model     │     │  Projector   │     │   Model     │
│   (MySQL)   │     │              │     │  (MongoDB)  │
└─────────────┘     └─────────────┘     └─────────────┘
     │                    │                    │
     │                    ▼                    │
     │              ┌─────────────┐           │
     │              │  Change     │           │
     └─────────────▶│  Streams    │◀──────────┘
                    └─────────────┘
```

## Implementation

### Command Model (MySQL)

```sql
-- commands.sql
CREATE TABLE account_commands (
  command_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  command_uuid CHAR(36) NOT NULL UNIQUE,
  customer_id BIGINT UNSIGNED NOT NULL,
  command_type VARCHAR(50) NOT NULL,
  command_data JSON NOT NULL,
  status ENUM('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED') DEFAULT 'PENDING',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  processed_at TIMESTAMP NULL,
  error_message TEXT NULL,
  INDEX idx_customer_status (customer_id, status),
  INDEX idx_created_at (created_at),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE account_events (
  event_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  event_uuid CHAR(36) NOT NULL UNIQUE,
  command_id BIGINT UNSIGNED NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  event_data JSON NOT NULL,
  event_version INT NOT NULL DEFAULT 1,
  aggregate_id BIGINT UNSIGNED NOT NULL,
  aggregate_type VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_command_id (command_id),
  INDEX idx_event_type (event_type),
  INDEX idx_aggregate (aggregate_type, aggregate_id),
  INDEX idx_created_at (created_at),
  FOREIGN KEY (command_id) REFERENCES account_commands(command_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Event types
-- ACCOUNT_CREATED
-- BALANCE_UPDATED
-- TRANSACTION_RECORDED
-- ACCOUNT_FROZEN
-- ACCOUNT_CLOSED
```

### Command Handler

```javascript
// command-handler.js
const mysql = require('./mysql-client');
const { v4: uuidv4 } = require('uuid');

class AccountCommandHandler {
  async createAccount(commandData) {
    const commandId = await this.createCommand({
      customer_id: commandData.customerId,
      command_type: 'CREATE_ACCOUNT',
      command_data: commandData
    });
    
    try {
      // Execute command in MySQL
      const result = await mysql.query(
        `CALL create_account(?, ?, ?, @account_id, @account_number)`,
        [
          commandData.customerId,
          commandData.accountType,
          commandData.initialBalance || 0
        ]
      );
      
      const accountResult = await mysql.query('SELECT @account_id as account_id, @account_number as account_number');
      const { account_id, account_number } = accountResult[0];
      
      // Emit event
      await this.emitEvent({
        command_id: commandId,
        event_type: 'ACCOUNT_CREATED',
        event_data: {
          account_id,
          account_number,
          customer_id: commandData.customerId,
          account_type: commandData.accountType,
          initial_balance: commandData.initialBalance || 0
        },
        aggregate_id: account_id,
        aggregate_type: 'ACCOUNT'
      });
      
      await this.completeCommand(commandId);
      
      return { account_id, account_number };
    } catch (error) {
      await this.failCommand(commandId, error.message);
      throw error;
    }
  }
  
  async updateBalance(commandData) {
    const commandId = await this.createCommand({
      customer_id: commandData.customerId,
      command_type: 'UPDATE_BALANCE',
      command_data: commandData
    });
    
    try {
      // Execute command in MySQL
      await mysql.query(
        `UPDATE accounts 
         SET balance = balance + ?, 
             available_balance = available_balance + ?,
             updated_at = NOW()
         WHERE account_id = ?`,
        [commandData.amount, commandData.amount, commandData.accountId]
      );
      
      // Get updated balance
      const account = await mysql.query(
        `SELECT balance, available_balance FROM accounts WHERE account_id = ?`,
        [commandData.accountId]
      );
      
      // Emit event
      await this.emitEvent({
        command_id: commandId,
        event_type: 'BALANCE_UPDATED',
        event_data: {
          account_id: commandData.accountId,
          customer_id: commandData.customerId,
          amount: commandData.amount,
          balance: account[0].balance,
          available_balance: account[0].available_balance
        },
        aggregate_id: commandData.accountId,
        aggregate_type: 'ACCOUNT'
      });
      
      await this.completeCommand(commandId);
      
      return account[0];
    } catch (error) {
      await this.failCommand(commandId, error.message);
      throw error;
    }
  }
  
  async createCommand(commandData) {
    const result = await mysql.query(
      `INSERT INTO account_commands 
       (command_uuid, customer_id, command_type, command_data, status) 
       VALUES (?, ?, ?, ?, 'PENDING')`,
      [uuidv4(), commandData.customer_id, commandData.command_type, JSON.stringify(commandData)]
    );
    
    return result.insertId;
  }
  
  async emitEvent(eventData) {
    await mysql.query(
      `INSERT INTO account_events 
       (event_uuid, command_id, event_type, event_data, aggregate_id, aggregate_type, event_version) 
       VALUES (?, ?, ?, ?, ?, ?, 1)`,
      [
        uuidv4(),
        eventData.command_id,
        eventData.event_type,
        JSON.stringify(eventData.event_data),
        eventData.aggregate_id,
        eventData.aggregate_type
      ]
    );
    
    // Publish to event bus for projection
    await this.publishToEventBus(eventData);
  }
  
  async publishToEventBus(eventData) {
    // Publish to Kafka/RabbitMQ for event projector
    const eventBus = require('./event-bus');
    await eventBus.publish('account.events', eventData);
  }
  
  async completeCommand(commandId) {
    await mysql.query(
      `UPDATE account_commands 
       SET status = 'COMPLETED', processed_at = NOW() 
       WHERE command_id = ?`,
      [commandId]
    );
  }
  
  async failCommand(commandId, errorMessage) {
    await mysql.query(
      `UPDATE account_commands 
       SET status = 'FAILED', error_message = ? 
       WHERE command_id = ?`,
      [errorMessage, commandId]
    );
  }
}

module.exports = AccountCommandHandler;
```

### Event Projector

```javascript
// event-projector.js
const mongodb = require('./mongodb-client');
const mysql = require('./mysql-client');
const eventBus = require('./event-bus');

class EventProjector {
  constructor() {
    this.projectors = new Map();
    this.setupProjectors();
  }
  
  setupProjectors() {
    // Account created projector
    this.projectors.set('ACCOUNT_CREATED', async (event) => {
      await this.projectAccountCreated(event);
    });
    
    // Balance updated projector
    this.projectors.set('BALANCE_UPDATED', async (event) => {
      await this.projectBalanceUpdated(event);
    });
    
    // Transaction recorded projector
    this.projectors.set('TRANSACTION_RECORDED', async (event) => {
      await this.projectTransactionRecorded(event);
    });
  }
  
  async projectAccountCreated(event) {
    const { account_id, customer_id, account_type, initial_balance } = event.event_data;
    
    // Update customer view in MongoDB
    await mongodb.collection('customers').updateOne(
      { customer_id },
      {
        $push: {
          accounts: {
            account_id,
            account_type,
            balance: initial_balance,
            available_balance: initial_balance,
            status: 'ACTIVE',
            opened_date: new Date(),
            last_transaction: null
          }
        },
        $set: {
          updated_at: new Date()
        }
      }
    );
    
    console.log(`[Projector] Account ${account_id} created for customer ${customer_id}`);
  }
  
  async projectBalanceUpdated(event) {
    const { account_id, customer_id, amount, balance, available_balance } = event.event_data;
    
    // Update account balance in customer view
    await mongodb.collection('customers').updateOne(
      {
        customer_id,
        'accounts.account_id': account_id
      },
      {
        $set: {
          'accounts.$.balance': balance,
          'accounts.$.available_balance': available_balance,
          'accounts.$.last_transaction': new Date(),
          updated_at: new Date()
        }
      }
    );
    
    console.log(`[Projector] Balance updated for account ${account_id}: ${balance}`);
  }
  
  async projectTransactionRecorded(event) {
    const { transaction_id, customer_id, account_id, amount, transaction_type, timestamp } = event.event_data;
    
    // Insert into time-series collection
    await mongodb.collection('transactions_ts').insertOne({
      timestamp: new Date(timestamp),
      customer_id,
      transaction_id,
      account_id,
      transaction_type,
      amount,
      status: 'COMPLETED'
    });
    
    // Update customer transaction summary
    await mongodb.collection('customers').updateOne(
      { customer_id },
      {
        $inc: {
          'transactions.last_30_days_count': 1,
          'transactions.last_90_days_count': 1,
          'transactions.last_year_count': 1,
          'transactions.total_lifetime_count': 1
        },
        $set: {
          'transactions.last_transaction_date': new Date(timestamp),
          updated_at: new Date()
        }
      }
    );
    
    console.log(`[Projector] Transaction ${transaction_id} recorded for customer ${customer_id}`);
  }
  
  async processEvent(event) {
    const projector = this.projectors.get(event.event_type);
    
    if (!projector) {
      console.warn(`[Projector] No projector found for event type: ${event.event_type}`);
      return;
    }
    
    try {
      // Check for duplicate processing using idempotency key
      const processed = await mongodb.collection('processed_events').findOne({
        event_uuid: event.event_uuid
      });
      
      if (processed) {
        console.log(`[Projector] Event ${event.event_uuid} already processed, skipping`);
        return;
      }
      
      // Process event
      await projector(event);
      
      // Mark as processed
      await mongodb.collection('processed_events').insertOne({
        event_uuid: event.event_uuid,
        event_type: event.event_type,
        processed_at: new Date()
      });
      
    } catch (error) {
      console.error(`[Projector] Error processing event ${event.event_uuid}:`, error);
      throw error;
    }
  }
  
  async start() {
    // Subscribe to event bus
    await eventBus.subscribe('account.events', async (event) => {
      await this.processEvent(event);
    });
    
    // Also listen to MySQL binary logs via change streams
    await this.listenToMySQLChangeStreams();
  }
  
  async listenToMySQLChangeStreams() {
    // Use MySQL binlog replication or Debezium to stream changes
    // This is a simplified example
    const mysqlChangeStream = require('./mysql-change-stream');
    
    mysqlChangeStream.on('event', async (event) => {
      if (event.table === 'account_events') {
        await this.processEvent(event);
      }
    });
  }
}

module.exports = EventProjector;
```

### Query Model (MongoDB)

```javascript
// query-handler.js
const mongodb = require('./mongodb-client');

class AccountQueryHandler {
  async getCustomer360View(customerId) {
    return await mongodb.collection('customers').findOne(
      { customer_id: customerId },
      {
        projection: {
          _id: 0,
          customer_id: 1,
          personal_info: 1,
          accounts: 1,
          transactions: 1,
          preferences: 1,
          risk_score: 1,
          behavior: 1,
          products: 1
        }
      }
    );
  }
  
  async getCustomerAccounts(customerId) {
    const customer = await mongodb.collection('customers').findOne(
      { customer_id: customerId },
      { projection: { accounts: 1 } }
    );
    
    return customer?.accounts || [];
  }
  
  async getCustomerTransactions(customerId, startDate, endDate) {
    return await mongodb.collection('transactions_ts').find({
      customer_id: customerId,
      timestamp: {
        $gte: startDate,
        $lt: endDate
      }
    }).sort({ timestamp: -1 }).toArray();
  }
  
  async searchCustomers(query, filters = {}) {
    const searchPipeline = [
      {
        $search: {
          index: 'customer_search',
          text: {
            query: query,
            path: ['personal_info.name', 'personal_info.email']
          }
        }
      }
    ];
    
    if (Object.keys(filters).length > 0) {
      searchPipeline.push({
        $match: filters
      });
    }
    
    return await mongodb.collection('customers').aggregate(searchPipeline).toArray();
  }
  
  async getCustomerAnalytics(customerId, period = 'monthly') {
    const collectionName = `customer_analytics_${period}`;
    return await mongodb.collection(collectionName).find({
      customer_id: customerId
    }).sort({ 'period.year': -1, 'period.month': -1 }).toArray();
  }
}

module.exports = AccountQueryHandler;
```

### Consistency Validator

```javascript
// consistency-validator.js
const mysql = require('./mysql-client');
const mongodb = require('./mongodb-client');

class ConsistencyValidator {
  async validateConsistency(customerId) {
    // Get data from MySQL (command model)
    const mysqlAccounts = await mysql.query(
      `SELECT account_id, balance, available_balance 
       FROM accounts 
       WHERE customer_id = ?`,
      [customerId]
    );
    
    // Get data from MongoDB (query model)
    const mongoCustomer = await mongodb.collection('customers').findOne(
      { customer_id: customerId },
      { projection: { accounts: 1 } }
    );
    
    // Compare balances
    const inconsistencies = [];
    
    for (const mysqlAccount of mysqlAccounts) {
      const mongoAccount = mongoCustomer?.accounts?.find(
        acc => acc.account_id === mysqlAccount.account_id
      );
      
      if (!mongoAccount) {
        inconsistencies.push({
          account_id: mysqlAccount.account_id,
          issue: 'Account missing in MongoDB',
          mysql_balance: mysqlAccount.balance
        });
      } else if (
        Math.abs(parseFloat(mysqlAccount.balance) - parseFloat(mongoAccount.balance)) > 0.01
      ) {
        inconsistencies.push({
          account_id: mysqlAccount.account_id,
          issue: 'Balance mismatch',
          mysql_balance: mysqlAccount.balance,
          mongo_balance: mongoAccount.balance,
          difference: Math.abs(parseFloat(mysqlAccount.balance) - parseFloat(mongoAccount.balance))
        });
      }
    }
    
    // Check vector clocks for ordering
    const mysqlClock = await this.getVectorClock('mysql', customerId);
    const mongoClock = await this.getVectorClock('mongodb', customerId);
    
    const isConsistent = this.isVectorClockConsistent(mysqlClock, mongoClock);
    
    return {
      customer_id: customerId,
      consistent: inconsistencies.length === 0 && isConsistent,
      inconsistencies,
      vector_clocks: {
        mysql: mysqlClock,
        mongodb: mongoClock,
        consistent: isConsistent
      }
    };
  }
  
  async getVectorClock(system, customerId) {
    if (system === 'mysql') {
      const result = await mysql.query(
        `SELECT MAX(event_id) as last_event_id 
         FROM account_events 
         WHERE aggregate_id IN (
           SELECT account_id FROM accounts WHERE customer_id = ?
         )`,
        [customerId]
      );
      return { system: 'mysql', last_event_id: result[0].last_event_id || 0 };
    } else {
      const result = await mongodb.collection('processed_events').findOne(
        { customer_id: customerId },
        { sort: { processed_at: -1 } }
      );
      return { 
        system: 'mongodb', 
        last_event_id: result?.event_id || 0,
        processed_at: result?.processed_at || null
      };
    }
  }
  
  isVectorClockConsistent(mysqlClock, mongoClock) {
    // Simple consistency check - in production, use proper vector clock comparison
    // MongoDB should have processed all events up to MySQL's last event
    return mongoClock.last_event_id >= mysqlClock.last_event_id;
  }
  
  async triggerReconciliation(customerId) {
    console.log(`[ConsistencyValidator] Triggering reconciliation for customer ${customerId}`);
    
    // Re-project all events for this customer
    const events = await mysql.query(
      `SELECT e.* 
       FROM account_events e
       INNER JOIN accounts a ON e.aggregate_id = a.account_id
       WHERE a.customer_id = ?
       ORDER BY e.event_id ASC`,
      [customerId]
    );
    
    const projector = require('./event-projector');
    
    for (const event of events) {
      await projector.processEvent({
        event_uuid: event.event_uuid,
        event_type: event.event_type,
        event_data: JSON.parse(event.event_data),
        aggregate_id: event.aggregate_id,
        aggregate_type: event.aggregate_type
      });
    }
    
    console.log(`[ConsistencyValidator] Reconciliation completed for customer ${customerId}`);
  }
}

module.exports = ConsistencyValidator;
```

### Usage Example

```javascript
// application.js
const AccountCommandHandler = require('./command-handler');
const AccountQueryHandler = require('./query-handler');
const ConsistencyValidator = require('./consistency-validator');

// Write operation (Command)
async function createAccount(customerId, accountType, initialBalance) {
  const commandHandler = new AccountCommandHandler();
  return await commandHandler.createAccount({
    customerId,
    accountType,
    initialBalance
  });
}

// Read operation (Query)
async function getCustomerView(customerId) {
  const queryHandler = new AccountQueryHandler();
  return await queryHandler.getCustomer360View(customerId);
}

// Consistency check
async function validateCustomerData(customerId) {
  const validator = new ConsistencyValidator();
  const result = await validator.validateConsistency(customerId);
  
  if (!result.consistent) {
    await validator.triggerReconciliation(customerId);
  }
  
  return result;
}
```

## Monitoring

### Key Metrics

- Event projection lag (time between event creation and projection)
- Consistency validation results
- Query performance (P50, P95, P99)
- Command processing time
- Event processing throughput

### Alerts

- Projection lag > 5 seconds
- Consistency validation failures > 1%
- Query latency P99 > 100ms
- Command processing failures

## Best Practices

1. **Idempotency**: All projectors must be idempotent
2. **Event Ordering**: Process events in order using event IDs
3. **Deduplication**: Track processed events to avoid duplicates
4. **Consistency Checks**: Regularly validate consistency between models
5. **Reconciliation**: Automatically reconcile inconsistencies
6. **Monitoring**: Track projection lag and consistency metrics
7. **Error Handling**: Implement retry logic for failed projections
