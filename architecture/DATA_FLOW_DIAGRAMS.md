# Data Flow Diagrams

## Consistency Boundaries and Data Flow

## Overview

This document provides data flow diagrams showing how data moves through the hybrid database system, including consistency boundaries and event flows.

## System Overview Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   Payments   │  │    Loans     │  │    Cards     │        │
│  │   Service    │  │   Service     │  │   Service    │        │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
└─────────┼──────────────────┼──────────────────┼────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    API Gateway / Load Balancer                  │
└─────────┬──────────────────┬──────────────────┬──────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Consistency Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │    Saga      │  │     CQRS     │  │   Data Mesh  │        │
│  │ Orchestrator │  │  Projector   │  │   Gateway    │        │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
└─────────┼──────────────────┼──────────────────┼────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Database Layer                               │
│  ┌──────────────┐                    ┌──────────────┐        │
│  │   MySQL 8.0  │                    │ MongoDB 6.0+  │        │
│  │ (Tier 1)     │                    │ (Tier 2)     │        │
│  │              │                    │              │        │
│  │ • Accounts   │                    │ • Customers  │        │
│  │ • Transactions│                   │ • Analytics  │        │
│  │ • Audit Log  │                    │ • Events     │        │
│  └──────┬───────┘                    └──────┬───────┘        │
└─────────┼─────────────────────────────────────┼────────────────┘
          │                                    │
          ▼                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Event Bus (Kafka)                            │
│  • Change Streams                                               │
│  • Event Sourcing                                               │
│  • Dead Letter Queue                                            │
└─────────────────────────────────────────────────────────────────┘
```

## Saga Pattern Data Flow

```
Transfer Request
       │
       ▼
┌──────────────┐
│ Saga Start   │
│ (Generate    │
│  Saga ID)    │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────┐
│ Step 1: Debit Source Account      │
│ (MySQL - Strong Consistency)       │
│                                    │
│ UPDATE accounts                    │
│ SET balance = balance - amount    │
│ WHERE account_id = from_account   │
└──────┬────────────────────────────┘
       │
       │ Event: ACCOUNT_DEBITED
       ▼
┌─────────────────────────────────────┐
│ Step 2: Credit Destination Account │
│ (MySQL - Strong Consistency)       │
│                                    │
│ UPDATE accounts                    │
│ SET balance = balance + amount    │
│ WHERE account_id = to_account     │
└──────┬────────────────────────────┘
       │
       │ Event: ACCOUNT_CREDITED
       ▼
┌─────────────────────────────────────┐
│ Step 3: Update Customer View      │
│ (MongoDB - Eventual Consistency)  │
│                                    │
│ UPDATE customers                   │
│ SET transactions.last_30_days++   │
│ WHERE customer_id = X             │
└──────┬────────────────────────────┘
       │
       │ Event: CUSTOMER_VIEW_UPDATED
       ▼
┌──────────────┐
│ Saga Complete│
│ (Success)    │
└──────────────┘

Error Path:
       │
       ▼
┌──────────────┐
│ Compensation │
│ (Rollback)   │
└──────────────┘
```

## CQRS Pattern Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    COMMAND SIDE (MySQL)                     │
│                                                              │
│  Write Request                                               │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────────┐                                           │
│  │   Command    │                                           │
│  │   Handler    │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ Execute      │                                           │
│  │ Command      │                                           │
│  │ (MySQL)      │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ Emit Event   │                                           │
│  │ (Event Store)│                                           │
│  └──────┬───────┘                                           │
└─────────┼────────────────────────────────────────────────────┘
          │
          │ Event Published
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    EVENT BUS (Kafka)                        │
│                                                              │
│  Topic: account.events                                      │
│  • ACCOUNT_CREATED                                          │
│  • BALANCE_UPDATED                                          │
│  • TRANSACTION_RECORDED                                     │
└─────────┬────────────────────────────────────────────────────┘
          │
          │ Event Consumed
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    QUERY SIDE (MongoDB)                     │
│                                                              │
│  ┌──────────────┐                                           │
│  │   Event      │                                           │
│  │  Projector   │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ Project Event│                                           │
│  │ (MongoDB)    │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │ Update Query │                                           │
│  │ Model        │                                           │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘

Read Request:
       │
       ▼
┌──────────────┐
│ Query Handler│
│ (MongoDB)    │
└──────────────┘
```

## Data Mesh Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│              Payments Domain (Data Product Owner)          │
│                                                              │
│  ┌──────────────┐                                           │
│  │   Payments   │                                           │
│  │   Service    │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         │ Write                                              │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │   MySQL      │                                           │
│  │  (Payments)  │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         │ Data Contract Validation                          │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │   MongoDB    │                                           │
│  │ (Analytics)  │                                           │
│  └──────┬───────┘                                           │
└─────────┼────────────────────────────────────────────────────┘
          │
          │ Data Product API
          ▼
┌─────────────────────────────────────────────────────────────┐
│              Federated Governance Layer                      │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Schema     │  │   Quality   │  │   Access     │      │
│  │ Validation   │  │  Monitoring │  │  Control    │      │
│  └──────┬───────┘  └──────┬──────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│              Consumer Services                               │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Fraud     │  │  Analytics   │  │  Reporting   │      │
│  │  Detection   │  │  Platform    │  │  Service     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Change Streams Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    MongoDB (Source)                         │
│                                                              │
│  Document Insert/Update/Delete                             │
│       │                                                      │
│       ▼                                                      │
│  Oplog Entry Created                                        │
│       │                                                      │
│       ▼                                                      │
│  Change Stream Event                                        │
└─────────┬────────────────────────────────────────────────────┘
          │
          │ Change Stream
          ▼
┌─────────────────────────────────────────────────────────────┐
│              Change Stream Consumers                         │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   CQRS       │  │    Fraud     │  │   Analytics  │      │
│  │  Projector   │  │  Detection   │  │   Pipeline   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│              Target Systems                                  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   MySQL      │  │   ML Model   │  │   Data      │      │
│  │  (Sync)      │  │  (Real-time) │  │  Warehouse  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Consistency Boundaries

### Strong Consistency Boundary (MySQL)

```
┌─────────────────────────────────────────────────────────────┐
│              Strong Consistency (ACID)                     │
│                                                              │
│  ┌──────────────┐                                           │
│  │   Account    │                                           │
│  │   Balance    │                                           │
│  │              │                                           │
│  │  UPDATE      │                                           │
│  │  accounts    │                                           │
│  │  SET balance │                                           │
│  └──────────────┘                                           │
│                                                              │
│  Guarantees:                                                │
│  • Immediate consistency                                    │
│  • ACID transactions                                        │
│  • No stale reads                                           │
└─────────────────────────────────────────────────────────────┘
```

### Eventual Consistency Boundary (MongoDB)

```
┌─────────────────────────────────────────────────────────────┐
│           Eventual Consistency (BASE)                       │
│                                                              │
│  ┌──────────────┐                                           │
│  │   Customer   │                                           │
│  │     View     │                                           │
│  │              │                                           │
│  │  UPDATE      │                                           │
│  │  customers   │                                           │
│  │  SET ...     │                                           │
│  └──────────────┘                                           │
│                                                              │
│  Guarantees:                                                │
│  • Eventually consistent                                    │
│  • High availability                                        │
│  • Optimized for reads                                      │
│                                                              │
│  Consistency Lag: <1 second                                 │
└─────────────────────────────────────────────────────────────┘
```

## Cross-Database Consistency Flow

```
MySQL Transaction
       │
       │ Strong Consistency
       ▼
┌──────────────┐
│   Commit     │
│   (ACID)     │
└──────┬───────┘
       │
       │ Emit Event
       ▼
┌──────────────┐
│  Event Bus   │
│  (Kafka)     │
└──────┬───────┘
       │
       │ Event Propagation
       │ (<1 second)
       ▼
┌──────────────┐
│   MongoDB     │
│   Update      │
│   (Eventual)  │
└──────────────┘

Consistency Validation:
       │
       ▼
┌──────────────┐
│   Vector     │
│   Clock      │
│   Check      │
└──────────────┘
       │
       │ If inconsistent
       ▼
┌──────────────┐
│ Reconciliation│
│   Trigger     │
└──────────────┘
```

## Performance Data Flow

### Hot Path (MongoDB Reads)

```
Read Request (<10ms target)
       │
       ▼
┌──────────────┐
│  Connection  │
│    Pool      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Read       │
│   Replica    │
│   (Local)    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Index      │
│   Lookup     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Cache      │
│   Check      │
│   (Redis)    │
└──────┬───────┘
       │
       │ Cache Hit
       ▼
Response (<5ms)
```

### Warm Path (MySQL Writes)

```
Write Request (<50ms target)
       │
       ▼
┌──────────────┐
│  Connection  │
│    Pool      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Primary    │
│    Node      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Write      │
│   (InnoDB)   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Binary     │
│    Log       │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Replication │
│  (Semi-sync) │
└──────┬───────┘
       │
       │ Commit
       ▼
Response (<30ms)
```

## Security Data Flow

```
Request
   │
   │ TLS 1.3 Encrypted
   ▼
┌──────────────┐
│   API        │
│  Gateway     │
└──────┬───────┘
       │
       │ Authentication
       ▼
┌──────────────┐
│   RBAC/ABAC  │
│   Check      │
└──────┬───────┘
       │
       │ Authorized
       ▼
┌──────────────┐
│   Database   │
│  (Encrypted) │
└──────┬───────┘
       │
       │ Encrypted Response
       ▼
Response
```

## Summary

These data flow diagrams illustrate:

1. **System Architecture**: How components interact
2. **Consistency Patterns**: Saga, CQRS, Data Mesh flows
3. **Event Propagation**: Change streams and event bus
4. **Consistency Boundaries**: Strong vs eventual consistency
5. **Performance Paths**: Hot and warm path optimizations
6. **Security Flow**: Encryption and access control

All flows are designed to meet the requirements:

- Sub-50ms P99 latency
- Zero data loss (RPO=0)
- 4-second failover (RTO=4s)
- 99.999% availability
