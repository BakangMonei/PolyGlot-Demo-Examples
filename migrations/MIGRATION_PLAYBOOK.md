# Migration Playbook

## Zero-Downtime Database Migrations

## Overview

This playbook provides procedures for performing zero-downtime migrations including schema changes, data migrations, and system upgrades.

## Migration Types

### Type 1: Schema Changes (Additive)

**Examples:**

- Adding new columns
- Adding new indexes
- Adding new tables

**Procedure:**

#### Step 1: Pre-Migration Validation

```sql
-- Verify current schema version
SELECT schema_version FROM schema_migrations ORDER BY version DESC LIMIT 1;

-- Check table sizes
SELECT
  table_name,
  ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
FROM information_schema.TABLES
WHERE table_schema = 'banking'
ORDER BY size_mb DESC;
```

#### Step 2: Create Migration Script

```sql
-- migration_001_add_customer_preferences.sql
-- Version: 001
-- Description: Add customer preferences table
-- Rollback: Yes

START TRANSACTION;

-- Add new table
CREATE TABLE customer_preferences (
  preference_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  preference_key VARCHAR(100) NOT NULL,
  preference_value JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  UNIQUE KEY uk_customer_preference (customer_id, preference_key),
  INDEX idx_customer_id (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Record migration
INSERT INTO schema_migrations (version, description, applied_at)
VALUES (001, 'Add customer preferences table', NOW());

COMMIT;
```

#### Step 3: Apply Migration (Blue-Green)

```bash
# Apply to blue environment first
mysql -h mysql-blue -u root -p < migration_001_add_customer_preferences.sql

# Verify migration
mysql -h mysql-blue -u root -p -e "SELECT * FROM schema_migrations WHERE version = 001;"

# Test application with new schema
# Run smoke tests

# Apply to green environment
mysql -h mysql-green -u root -p < migration_001_add_customer_preferences.sql

# Switch traffic
# Update ProxySQL to point to green
```

#### Step 4: Rollback Procedure (if needed)

```sql
-- rollback_001.sql
START TRANSACTION;

DROP TABLE IF EXISTS customer_preferences;

DELETE FROM schema_migrations WHERE version = 001;

COMMIT;
```

### Type 2: Schema Changes (Modifying)

**Examples:**

- Modifying column types
- Dropping columns
- Renaming columns

**Procedure:**

#### Step 1: Create Backward-Compatible Migration

```sql
-- migration_002_modify_account_balance.sql
-- Version: 002
-- Description: Change balance column from DECIMAL(15,2) to DECIMAL(20,2)
-- Strategy: Add new column, migrate data, switch, drop old

START TRANSACTION;

-- Add new column
ALTER TABLE accounts
ADD COLUMN balance_new DECIMAL(20,2) NOT NULL DEFAULT 0.00 AFTER balance;

-- Migrate data
UPDATE accounts SET balance_new = balance;

-- Add index on new column
CREATE INDEX idx_balance_new ON accounts(balance_new);

COMMIT;
```

#### Step 2: Application Update

```javascript
// Update application to write to both columns
async function updateBalance(accountId, amount) {
  await mysql.query(
    `UPDATE accounts 
     SET balance = balance + ?, 
         balance_new = balance_new + ?
     WHERE account_id = ?`,
    [amount, amount, accountId]
  );
}
```

#### Step 3: Switch to New Column

```sql
-- migration_002_switch.sql
START TRANSACTION;

-- Rename columns
ALTER TABLE accounts
CHANGE COLUMN balance balance_old DECIMAL(15,2),
CHANGE COLUMN balance_new balance DECIMAL(20,2);

-- Drop old index, add new
DROP INDEX idx_balance ON accounts;
CREATE INDEX idx_balance ON accounts(balance);

COMMIT;
```

#### Step 4: Cleanup

```sql
-- migration_002_cleanup.sql
START TRANSACTION;

-- Drop old column (after verification period)
ALTER TABLE accounts DROP COLUMN balance_old;

COMMIT;
```

### Type 3: Data Migrations

**Examples:**

- Migrating data between tables
- Data transformations
- Data archival

**Procedure:**

#### Step 1: Create Migration Script

```javascript
// migration_003_archive_old_transactions.js
const mysql = require("./mysql-client");
const mongodb = require("./mongodb-client");

async function archiveOldTransactions() {
  const cutoffDate = new Date("2024-01-01");

  // Find transactions to archive
  const transactions = await mysql.query(
    `SELECT * FROM transactions 
     WHERE transaction_date < ? 
     ORDER BY transaction_id 
     LIMIT 10000`,
    [cutoffDate]
  );

  // Archive to MongoDB
  for (const transaction of transactions) {
    await mongodb.collection("transactions_archive").insertOne({
      ...transaction,
      archived_at: new Date(),
    });

    // Mark as archived in MySQL
    await mysql.query(
      `UPDATE transactions 
       SET archived = 1 
       WHERE transaction_id = ?`,
      [transaction.transaction_id]
    );
  }

  // Verify migration
  const archivedCount = await mongodb
    .collection("transactions_archive")
    .countDocuments({
      archived_at: { $gte: new Date() },
    });

  console.log(`Archived ${archivedCount} transactions`);
}

// Run in batches
async function runMigration() {
  let batch = 1;
  while (true) {
    console.log(`Processing batch ${batch}`);
    const count = await archiveOldTransactions();
    if (count === 0) break;
    batch++;
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Rate limiting
  }
}
```

### Type 4: System Upgrades

**Examples:**

- MySQL version upgrade
- MongoDB version upgrade
- OS upgrades

**Procedure:**

#### Step 1: Pre-Upgrade Checklist

```bash
# Backup databases
./backup-mysql.sh
./backup-mongodb.sh

# Verify backups
mysql -u root -p < verify-backup.sql

# Check current versions
mysql --version
mongosh --eval "db.version()"

# Review release notes
# Test upgrade in staging environment
```

#### Step 2: Rolling Upgrade (MySQL)

```bash
# Upgrade secondary nodes first
# Node 1
systemctl stop mysql
apt-get install mysql-server-8.0.35
systemctl start mysql
mysql_upgrade -u root -p

# Verify replication
mysql -u root -p -e "SHOW SLAVE STATUS\G"

# Upgrade remaining secondaries
# Finally upgrade primary (with failover)
```

#### Step 3: Rolling Upgrade (MongoDB)

```bash
# Upgrade secondary nodes first
# Node 1
systemctl stop mongod
apt-get install mongodb-enterprise=6.0.5
systemctl start mongod

# Verify replica set
mongosh --eval "rs.status()"

# Upgrade remaining secondaries
# Step down primary and upgrade
mongosh --eval "rs.stepDown()"
# Upgrade former primary
```

## Migration Best Practices

### 1. Always Have a Rollback Plan

- Test rollback procedures in staging
- Document rollback steps
- Keep previous schema versions available

### 2. Use Feature Flags

```javascript
// Feature flag for gradual rollout
if (featureFlags.newSchemaEnabled) {
  // Use new schema
  await useNewSchema();
} else {
  // Use old schema
  await useOldSchema();
}
```

### 3. Monitor During Migration

- Monitor application errors
- Monitor database performance
- Monitor replication lag
- Set up alerts for anomalies

### 4. Gradual Rollout

- Start with low-traffic periods
- Migrate small batches first
- Increase batch size gradually
- Monitor at each step

### 5. Communication

- Notify stakeholders before migration
- Provide status updates during migration
- Document any issues encountered
- Post-mortem after migration

## Migration Checklist

### Pre-Migration

- [ ] Backup all databases
- [ ] Verify backups are restorable
- [ ] Test migration in staging
- [ ] Review migration script
- [ ] Prepare rollback plan
- [ ] Notify stakeholders
- [ ] Schedule maintenance window (if needed)

### During Migration

- [ ] Apply migration script
- [ ] Verify migration success
- [ ] Run smoke tests
- [ ] Monitor application logs
- [ ] Monitor database metrics
- [ ] Check for errors

### Post-Migration

- [ ] Verify data integrity
- [ ] Monitor performance
- [ ] Update documentation
- [ ] Document lessons learned
- [ ] Update runbooks if needed

## Migration Tools

### Version Control

```sql
-- schema_migrations table
CREATE TABLE schema_migrations (
  version INT PRIMARY KEY,
  description VARCHAR(500),
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  applied_by VARCHAR(100),
  rollback_script TEXT,
  status ENUM('PENDING', 'APPLIED', 'ROLLED_BACK') DEFAULT 'PENDING'
);
```

### Migration Runner

```javascript
// migration-runner.js
const mysql = require("./mysql-client");
const fs = require("fs");
const path = require("path");

class MigrationRunner {
  async runMigrations() {
    const migrations = this.getPendingMigrations();

    for (const migration of migrations) {
      try {
        console.log(
          `Running migration ${migration.version}: ${migration.description}`
        );
        await this.applyMigration(migration);
        console.log(`Migration ${migration.version} completed`);
      } catch (error) {
        console.error(`Migration ${migration.version} failed:`, error);
        await this.rollbackMigration(migration);
        throw error;
      }
    }
  }

  async applyMigration(migration) {
    const script = fs.readFileSync(migration.path, "utf8");
    await mysql.query(script);

    await mysql.query(
      `INSERT INTO schema_migrations (version, description, applied_at, applied_by, status) 
       VALUES (?, ?, NOW(), USER(), 'APPLIED')`,
      [migration.version, migration.description]
    );
  }

  async rollbackMigration(migration) {
    if (migration.rollbackScript) {
      await mysql.query(migration.rollbackScript);
    }

    await mysql.query(
      `UPDATE schema_migrations 
       SET status = 'ROLLED_BACK' 
       WHERE version = ?`,
      [migration.version]
    );
  }

  getPendingMigrations() {
    // Read migration files from migrations/ directory
    const migrationsDir = path.join(__dirname, "migrations");
    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith(".sql"))
      .sort();

    return files.map((file) => ({
      version: parseInt(file.match(/\d+/)[0]),
      description: file.replace(".sql", ""),
      path: path.join(migrationsDir, file),
    }));
  }
}

module.exports = MigrationRunner;
```

## Common Migration Patterns

### Pattern 1: Add Column with Default

```sql
ALTER TABLE accounts
ADD COLUMN new_field VARCHAR(100) DEFAULT 'default_value'
AFTER existing_field;
```

### Pattern 2: Rename Column

```sql
-- Step 1: Add new column
ALTER TABLE accounts ADD COLUMN new_name VARCHAR(100);

-- Step 2: Migrate data
UPDATE accounts SET new_name = old_name;

-- Step 3: Switch application
-- Step 4: Drop old column
ALTER TABLE accounts DROP COLUMN old_name;
```

### Pattern 3: Change Column Type

```sql
-- Use same pattern as rename column
-- Add new column with new type
-- Migrate data
-- Switch application
-- Drop old column
```

## Monitoring Migrations

### Key Metrics

- Migration duration
- Data migration rate
- Application error rate
- Database performance impact
- Replication lag

### Alerts

- Migration failures
- High error rates during migration
- Performance degradation
- Data inconsistencies
