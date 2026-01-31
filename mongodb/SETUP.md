# MongoDB 6.0+ Enterprise Setup Guide

## Overview

This guide provides step-by-step instructions for deploying MongoDB 6.0+ Enterprise Edition as the System of Engagement for the global banking platform.

## Prerequisites

- MongoDB 6.0+ Enterprise Edition
- Minimum 3 nodes per shard (replica set)
- Network connectivity between regions
- SSL certificates for TLS 1.3
- AWS KMS or equivalent for CSFLE
- Atlas Search (if using MongoDB Atlas) or self-hosted search

## Installation

### Step 1: Install MongoDB 6.0+ Enterprise

```bash
# Import MongoDB public GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.com/apt/ubuntu focal/mongodb-enterprise/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-enterprise-6.0.list

# Update and install
sudo apt-get update
sudo apt-get install -y mongodb-enterprise

# Start MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod
```

### Step 2: Configure MongoDB

Edit `/etc/mongod.conf`:

```yaml
# Network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/mongodb/ssl/server.pem
    CAFile: /etc/mongodb/ssl/ca.pem
    allowConnectionsWithoutCertificates: false
    allowInvalidCertificates: false

# Storage
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 64
      journalCompressor: snappy
      directoryForIndexes: false
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true
    # Encryption at rest
    encryptionKeyFile: /etc/mongodb/encryption-key

# Security
security:
  authorization: enabled
  keyFile: /etc/mongodb/replica-set-key

# Replication
replication:
  replSetName: "banking-rs"
  oplogSizeMB: 10240

# Operation Profiling
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
  slowOpSampleRate: 0.1

# Logging
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen
  verbosity: 1
  component:
    accessControl:
      verbosity: 2
    command:
      verbosity: 1

# Process Management
processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
```

### Step 3: Initialize Replica Set

```javascript
// Connect to MongoDB
mongosh --tls --tlsCertificateKeyFile /etc/mongodb/ssl/client.pem

// Initialize replica set
rs.initiate({
  _id: "banking-rs",
  members: [
    { _id: 0, host: "mongodb-node1:27017", priority: 2 },
    { _id: 1, host: "mongodb-node2:27017", priority: 1 },
    { _id: 2, host: "mongodb-node3:27017", priority: 1, arbiterOnly: true }
  ]
});

// Check replica set status
rs.status();
```

### Step 4: Create Time-Series Collections

```javascript
// Create time-series collection for transactions
db.createCollection("transactions_ts", {
  timeseries: {
    timeField: "timestamp",
    metaField: "customer_id",
    granularity: "seconds",
    // bucketMaxSpanSeconds is not a valid option in MongoDB 6.0+
    // Bucket size is automatically managed by MongoDB
    bucketRoundingSeconds: 60,  // Optional: Round bucket boundaries
  },
  expireAfterSeconds: 63072000, // 2 years retention
});

// Create indexes
db.transactions_ts.createIndex({ customer_id: 1, timestamp: -1 });
db.transactions_ts.createIndex({ transaction_type: 1, timestamp: -1 });
db.transactions_ts.createIndex({ status: 1, timestamp: -1 });
db.transactions_ts.createIndex({ merchant_id: 1, timestamp: -1 });
```

### Step 5: Configure Change Streams

```javascript
// Enable change streams on collections
// Change streams are automatically available on replica sets

// Example: Watch transactions collection
const changeStream = db.transactions.watch(
  [{ $match: { operationType: { $in: ["insert", "update"] } } }],
  {
    fullDocument: "updateLookup",
    resumeAfter: null, // Set resume token for recovery
  }
);

// Process change events
changeStream.on("change", (change) => {
  console.log("Change detected:", change);
  // Process event for CQRS, fraud detection, etc.
});
```

### Step 6: Set Up Client-Side Field-Level Encryption (CSFLE)

#### Configure AWS KMS

```javascript
// Create encryption schema
const encryptionSchema = {
  "banking.customers": {
    bsonType: "object",
    encryptMetadata: {
      keyId: [UUID("your-aws-kms-key-id")],
    },
    properties: {
      "personal_info.ssn": {
        encrypt: {
          bsonType: "string",
          algorithm: "AEAD_AES_256_CBC_HMAC_SHA_512-Deterministic",
        },
      },
      "personal_info.date_of_birth": {
        encrypt: {
          bsonType: "date",
          algorithm: "AEAD_AES_256_CBC_HMAC_SHA_512-Random",
        },
      },
      "personal_info.account_number": {
        encrypt: {
          bsonType: "string",
          algorithm: "AEAD_AES_256_CBC_HMAC_SHA_512-Deterministic",
        },
      },
    },
  },
};

// Connect with encryption
const client = new MongoClient(uri, {
  autoEncryption: {
    keyVaultNamespace: "encryption.__keyVault",
    kmsProviders: {
      aws: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        sessionToken: process.env.AWS_SESSION_TOKEN, // Optional
      },
    },
    schemaMap: encryptionSchema,
  },
});
```

### Step 7: Configure Sharding

```javascript
// Enable sharding on database
sh.enableSharding("banking");

// Create sharded collection with zone sharding
sh.shardCollection(
  "banking.customers",
  { customer_id: 1 },
  {
    presplitHashedZones: true,
  }
);

// Create zones for data sovereignty
sh.addShardToZone("shard-eu-1", "EU");
sh.addShardToZone("shard-eu-2", "EU");
sh.addShardToZone("shard-us-1", "US");
sh.addShardToZone("shard-us-2", "US");

// Tag ranges to zones
sh.updateZoneKeyRange(
  "banking.customers",
  { customer_id: MinKey },
  { customer_id: 500000000 },
  "EU"
);

sh.updateZoneKeyRange(
  "banking.customers",
  { customer_id: 500000000 },
  { customer_id: MaxKey },
  "US"
);

// Check sharding status
sh.status();
```

### Step 8: Set Up Atlas Search (or Self-Hosted)

```javascript
// Create search index for customer search
db.customers.createSearchIndex({
  name: "customer_search",
  definition: {
    mappings: {
      dynamic: true,
      fields: {
        "personal_info.name": {
          type: "autocomplete",
          analyzer: "lucene.standard",
          searchAnalyzer: "lucene.english",
        },
        "personal_info.email": {
          type: "autocomplete",
          analyzer: "lucene.email",
        },
        "accounts.account_type": {
          type: "string",
          analyzer: "lucene.keyword",
        },
        risk_score: {
          type: "number",
        },
        "transactions.description": {
          type: "string",
          analyzer: "lucene.english",
        },
      },
    },
  },
});

// Faceted search query
db.customers.aggregate([
  {
    $search: {
      index: "customer_search",
      text: {
        query: "john doe",
        path: ["personal_info.name", "personal_info.email"],
      },
      facet: {
        operator: "and",
        facets: {
          accountTypes: {
            type: "string",
            path: "accounts.account_type",
          },
          riskLevels: {
            type: "number",
            path: "risk_score",
            boundaries: [0, 0.3, 0.7, 1.0],
          },
        },
      },
    },
  },
]);
```

### Step 9: Configure Distributed Transactions

```javascript
// Enable transactions on sharded cluster
// Transactions are enabled by default in MongoDB 4.2+

// Example distributed transaction
const session = client.startSession();

try {
  session.startTransaction({
    readConcern: { level: "snapshot" },
    writeConcern: { w: "majority", wtimeout: 5000 },
  });

  // Update customer in shard 1
  await customersCollection.updateOne(
    { customer_id: 123 },
    { $inc: { total_transactions: 1 } },
    { session }
  );

  // Insert transaction in shard 2
  await transactionsCollection.insertOne(
    {
      customer_id: 123,
      amount: 1000,
      timestamp: new Date(),
    },
    { session }
  );

  // Commit transaction
  await session.commitTransaction();
} catch (error) {
  await session.abortTransaction();
  throw error;
} finally {
  session.endSession();
}
```

### Step 10: Set Up Graph Queries for Fraud Detection

```javascript
// Create indexes for graph traversal
db.transactions.createIndex({ customer_id: 1, timestamp: -1 });
db.transactions.createIndex({ related_customer_id: 1 });
db.transactions.createIndex({ flagged: 1 });

// Fraud ring detection using $graphLookup
db.transactions.aggregate([
  {
    $match: {
      flagged: true,
      timestamp: { $gte: new Date("2026-01-01") },
    },
  },
  {
    $graphLookup: {
      from: "transactions",
      startWith: "$customer_id",
      connectFromField: "customer_id",
      connectToField: "related_customer_id",
      as: "connected_transactions",
      maxDepth: 3,
      restrictSearchWithMatch: {
        flagged: true,
        timestamp: { $gte: new Date("2026-01-01") },
      },
    },
  },
  {
    $match: {
      $expr: { $gt: [{ $size: "$connected_transactions" }, 5] },
    },
  },
  {
    $group: {
      _id: "$customer_id",
      fraud_ring_size: { $sum: 1 },
      connected_customers: {
        $addToSet: "$connected_transactions.customer_id",
      },
      total_suspicious_amount: { $sum: "$amount" },
    },
  },
  {
    $match: {
      fraud_ring_size: { $gte: 5 },
    },
  },
]);
```

### Step 11: Create Materialized Views

```javascript
// Real-time customer analytics materialized view
db.transactions.aggregate([
  {
    $match: {
      timestamp: {
        $gte: new Date("2026-01-01"),
        $lt: new Date("2026-02-01"),
      },
      status: "COMPLETED",
    },
  },
  {
    $group: {
      _id: "$customer_id",
      total_amount: { $sum: "$amount" },
      transaction_count: { $sum: 1 },
      avg_amount: { $avg: "$amount" },
      min_amount: { $min: "$amount" },
      max_amount: { $max: "$amount" },
      last_transaction: { $max: "$timestamp" },
      transaction_types: { $addToSet: "$transaction_type" },
    },
  },
  {
    $merge: {
      into: "customer_analytics_monthly",
      whenMatched: "replace",
      whenNotMatched: "insert",
    },
  },
]);

// Schedule this aggregation to run every hour
```

### Step 12: Set Up Wildcard Indexes

```javascript
// Create wildcard index for dynamic customer profile attributes
db.customers.createIndex({
  "profile.$**": 1,
  "preferences.$**": 1,
  "metadata.$**": 1,
});

// Query dynamic attributes efficiently
db.customers.find({
  "profile.custom_field_123": "value",
  "preferences.notification_email": true,
  "metadata.source": "mobile_app",
});
```

### Step 13: Configure Monitoring

```bash
# Install MongoDB Exporter for Prometheus
wget https://github.com/percona/mongodb_exporter/releases/download/v0.39.0/mongodb_exporter-0.39.0.linux-amd64.tar.gz
tar -xzf mongodb_exporter-0.39.0.linux-amd64.tar.gz
sudo cp mongodb_exporter /usr/local/bin/

# Create monitoring user
mongosh --tls --tlsCertificateKeyFile /etc/mongodb/ssl/client.pem <<EOF
use admin
db.createUser({
  user: "exporter",
  pwd: "exporter_password",
  roles: [
    { role: "clusterMonitor", db: "admin" },
    { role: "read", db: "local" }
  ]
})
EOF

# Start exporter
sudo systemctl enable mongodb_exporter
sudo systemctl start mongodb_exporter
```

## Verification

### Check Replica Set Status

```javascript
rs.status();
rs.printReplicationInfo();
rs.printSlaveReplicationInfo();
```

### Check Sharding Status

```javascript
sh.status();
db.stats();
db.customers.getShardDistribution();
```

### Check Encryption Status

```javascript
db.adminCommand({ getParameter: 1, encryptionOptions: 1 });
```

### Performance Test

```javascript
// Test write performance
const start = Date.now();
for (let i = 0; i < 1000; i++) {
  db.transactions_ts.insertOne({
    customer_id: Math.floor(Math.random() * 1000000),
    amount: Math.random() * 1000,
    transaction_type: "TRANSFER",
    timestamp: new Date(),
    status: "COMPLETED",
  });
}
const duration = Date.now() - start;
print(
  `Inserted 1000 documents in ${duration}ms (${
    (1000 / duration) * 1000
  } ops/sec)`
);

// Test read performance
const readStart = Date.now();
db.transactions_ts
  .find({
    customer_id: 123456,
    timestamp: { $gte: new Date("2026-01-01") },
  })
  .limit(100)
  .toArray();
const readDuration = Date.now() - readStart;
print(`Read query completed in ${readDuration}ms`);
```

## Troubleshooting

### Replica Set Issues

```javascript
// Check replica set status
rs.status();

// If node is DOWN, check logs
// /var/log/mongodb/mongod.log

// Rejoin node
rs.add({ host: "mongodb-node:27017", priority: 1 });
```

### Sharding Issues

```javascript
// Check shard distribution
sh.status();

// If shard is imbalanced, rebalance
sh.startBalancer();
sh.getBalancerState();

// Check chunk distribution
db.customers.getShardDistribution();
```

### Performance Issues

```javascript
// Check slow operations
db.currentOp({ active: true, secs_running: { $gt: 1 } });

// Check index usage
db.customers.aggregate([{ $indexStats: {} }]);

// Analyze query performance
db.customers.find({ customer_id: 123 }).explain("executionStats");
```

## Maintenance

### Daily Tasks

- Monitor replica set lag
- Check oplog size
- Review slow operations
- Verify backup completion

### Weekly Tasks

- Analyze index usage
- Review shard distribution
- Check disk space
- Review connection pool usage

### Monthly Tasks

- Rotate encryption keys
- Review security audit logs
- Capacity planning review
- Performance baseline comparison

## Backup and Recovery

See [Disaster Recovery Runbooks](../disaster-recovery/MONGODB_RECOVERY.md) for detailed backup and recovery procedures.
