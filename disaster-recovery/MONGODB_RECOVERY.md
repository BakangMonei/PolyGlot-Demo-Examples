# MongoDB Disaster Recovery Runbook

## Overview

This runbook provides step-by-step procedures for recovering MongoDB databases from various disaster scenarios.

## Scenario 1: Replica Set Primary Failure

### Symptoms

- Primary node is down
- Application cannot write to database
- Replica set elections occurring

### Recovery Procedure

#### Step 1: Verify Primary Failure

```javascript
// Check replica set status
rs.status();

// Check node health
db.serverStatus();
```

#### Step 2: Automatic Failover (if configured)

```javascript
// MongoDB should automatically elect new primary
// Verify new primary
rs.isMaster();

// Check replica set status
rs.status();
```

#### Step 3: Manual Failover (if needed)

```javascript
// On secondary node, force election
rs.stepDown();

// Or remove failed primary
rs.remove("mongodb-node1:27017");

// Add node back when recovered
rs.add({ host: "mongodb-node1:27017", priority: 1 });
```

#### Step 4: Update Application Configuration

```javascript
// Update connection string to include all nodes
const uri =
  "mongodb://mongodb-node1:27017,mongodb-node2:27017,mongodb-node3:27017/banking?replicaSet=banking-rs";
```

#### Step 5: Verify Data Consistency

```javascript
// Check oplog
rs.printReplicationInfo();

// Verify data on all nodes
db.customers.countDocuments({});
db.transactions_ts.countDocuments({});
```

**Recovery Time:** <30 seconds  
**Data Loss:** Zero (replica set replication)

---

## Scenario 2: Sharded Cluster Failure

### Symptoms

- Shard is unreachable
- Queries failing for specific shard ranges
- Config server issues

### Recovery Procedure

#### Step 1: Identify Failed Shard

```javascript
// Check shard status
sh.status();

// Check config server
db.getSiblingDB("config").shards.find();
```

#### Step 2: Remove Failed Shard

```javascript
// Remove shard from cluster
use admin
db.runCommand({ removeShard: "shard-1" })

// Wait for draining to complete
// Check status
db.getSiblingDB("config").shards.find()
```

#### Step 3: Restore Shard Data

```bash
# Restore shard from backup
mongorestore \
  --host mongodb-shard-1:27017 \
  --archive=/backups/mongodb/shard-1-$(date +%Y%m%d).archive \
  --gzip
```

#### Step 4: Re-add Shard

```javascript
// Add shard back to cluster
sh.addShard("shard-1/mongodb-shard-1-node1:27017,mongodb-shard-1-node2:27017");

// Verify shard is active
sh.status();
```

#### Step 5: Rebalance Data

```javascript
// Start balancer
sh.startBalancer();

// Check balancer status
sh.getBalancerState();

// Monitor rebalancing
sh.status();
```

**Recovery Time:** <1 hour  
**Data Loss:** Zero (backup restoration)

---

## Scenario 3: Data Corruption

### Symptoms

- Checksum errors
- Data inconsistencies
- Application errors

### Recovery Procedure

#### Step 1: Identify Corruption

```javascript
// Run database validation
db.runCommand({ validate: "customers", full: true });

// Check for corruption errors
db.getSiblingDB("admin").runCommand({ getLog: "global" });
```

#### Step 2: Stop Writes

```javascript
// Set read-only mode
db.adminCommand({ setParameter: 1, readOnly: true });
```

#### Step 3: Restore from Backup

```bash
# Identify last known good backup
ls -lth /backups/mongodb/

# Restore specific collection
mongorestore \
  --host localhost:27017 \
  --db banking \
  --collection customers \
  --archive=/backups/mongodb/banking-customers-20260130.archive \
  --gzip \
  --drop
```

#### Step 4: Replay Oplog

```javascript
// Replay oplog entries after backup timestamp
// Use mongorestore with oplog
mongorestore --oplogReplay /backups/mongodb/oplog.bson
```

#### Step 5: Verify Data Integrity

```javascript
// Run validation
db.runCommand({ validate: "customers", full: true });

// Verify record counts
db.customers.countDocuments({});
db.transactions_ts.countDocuments({});

// Cross-validate with source systems
```

#### Step 6: Resume Operations

```javascript
// Remove read-only mode
db.adminCommand({ setParameter: 1, readOnly: false });

// Resume replication
rs.slaveOk();
```

**Recovery Time:** <30 minutes  
**Data Loss:** Maximum 5 minutes (oplog replay)

---

## Scenario 4: Security Breach

### Symptoms

- Unauthorized access detected
- Suspicious queries in audit logs
- Data exfiltration alerts

### Recovery Procedure

#### Step 1: Immediate Isolation

```bash
# Block suspicious IPs
iptables -A INPUT -s <suspicious_ip> -j DROP

# Disable compromised users
mongosh <<EOF
use admin
db.dropUser("compromised_user")
EOF
```

#### Step 2: Forensic Data Capture

```bash
# Capture system state
ps aux > /forensics/process-list-$(date +%Y%m%d-%H%M%S).txt
netstat -tulpn > /forensics/network-connections-$(date +%Y%m%d-%H%M%S).txt

# Capture database state
mongodump --archive=/forensics/mongodb-dump-$(date +%Y%m%d-%H%M%S).archive

# Capture oplog
mongodump --db local --collection oplog.rs --archive=/forensics/oplog-$(date +%Y%m%d-%H%M%S).archive
```

#### Step 3: Golden Image Restoration

```bash
# Stop MongoDB
systemctl stop mongod

# Restore from golden image
rsync -av /golden-images/mongodb/ /var/lib/mongodb/

# Restore configuration
cp /golden-images/mongodb/mongod.conf /etc/mongod.conf

# Start MongoDB
systemctl start mongod
```

#### Step 4: Audit Trail Preservation

```javascript
// Export audit logs
db.audit_log
  .find({
    timestamp: { $gte: ISODate("2026-01-30T00:00:00Z") },
  })
  .forEach(function (doc) {
    printjson(doc);
  });
```

#### Step 5: Credential Rotation

```javascript
// Rotate all user passwords
use admin
db.changeUserPassword("app_user", "new_secure_password")
db.changeUserPassword("monitoring_user", "new_secure_password")

// Rotate keyfile
// Generate new keyfile
openssl rand -base64 756 > /etc/mongodb/replica-set-key-new
chmod 400 /etc/mongodb/replica-set-key-new

// Update on all nodes
// Restart MongoDB
```

#### Step 6: Security Patch Deployment

```bash
# Apply security patches
apt-get update
apt-get install mongodb-enterprise

# Verify patches
mongosh --eval "db.version()"
```

**Recovery Time:** <2 hours  
**Data Loss:** Zero (golden image restoration)

---

## Backup Procedures

### Daily Backups

```bash
#!/bin/bash
# daily-backup.sh

BACKUP_DIR="/backups/mongodb/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Full backup
mongodump \
  --host localhost:27017 \
  --archive=$BACKUP_DIR/full-backup-$(date +%Y%m%d-%H%M%S).archive \
  --gzip \
  --oplog

# Encrypt backup
openssl enc -aes-256-gcm -salt -pbkdf2 \
  -kfile /etc/backup-keys/mongodb-backup.key \
  -in $BACKUP_DIR/full-backup-$(date +%Y%m%d-%H%M%S).archive \
  -out $BACKUP_DIR/full-backup-$(date +%Y%m%d-%H%M%S).archive.enc

# Upload to S3
aws s3 cp $BACKUP_DIR/full-backup-$(date +%Y%m%d-%H%M%S).archive.enc \
  s3://backups-banking/mongodb/$(date +%Y%m%d)/

# Cleanup old backups (keep 30 days)
find /backups/mongodb -type f -mtime +30 -delete
```

### Incremental Backups (Oplog)

```bash
#!/bin/bash
# incremental-backup.sh

# Backup oplog only
mongodump \
  --host localhost:27017 \
  --db local \
  --collection oplog.rs \
  --archive=/backups/mongodb/oplog/oplog-$(date +%Y%m%d-%H%M%S).archive \
  --gzip \
  --query '{ts: {$gte: Timestamp('$(date +%s)', 0)}}'
```

### Point-in-Time Recovery

```bash
# Restore to specific point in time
mongorestore \
  --host localhost:27017 \
  --archive=/backups/mongodb/full-backup-20260130.archive \
  --gzip \
  --oplogReplay \
  --oplogLimit 1735689600  # Timestamp limit
```

## Testing Recovery Procedures

### Monthly DR Drill

1. **Schedule**: First Saturday of each month
2. **Scope**: Test one recovery scenario
3. **Documentation**: Document results and improvements
4. **Review**: Review with team and update procedures

### Recovery Time Objectives (RTO)

| Scenario                    | RTO | RPO |
| --------------------------- | --- | --- |
| Replica Set Primary Failure | 30s | 0s  |
| Sharded Cluster Failure     | 1h  | 0s  |
| Data Corruption             | 30m | 5m  |
| Security Breach             | 2h  | 0s  |

## Monitoring and Alerts

### Key Metrics

- Replica set lag
- Oplog size
- Backup success/failure
- Shard balance
- Disk space usage

### Alerts

- Replica set lag > 5 seconds
- Primary node down
- Backup failure
- Oplog size > 10GB
- Shard imbalance > 20%
