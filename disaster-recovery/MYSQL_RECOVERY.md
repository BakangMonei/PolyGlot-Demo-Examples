# MySQL Disaster Recovery Runbook

## Overview

This runbook provides step-by-step procedures for recovering MySQL databases from various disaster scenarios.

## Scenario 1: Regional Outage

### Symptoms

- Primary region (US-East) is unreachable
- Application cannot connect to MySQL
- Health checks failing

### Recovery Procedure

#### Step 1: Verify Outage

```bash
# Check primary region connectivity
ping mysql-primary-us-east.banking.com

# Check DNS resolution
nslookup mysql-primary-us-east.banking.com

# Check application logs
tail -f /var/log/app/error.log
```

#### Step 2: Failover to Secondary Region

```sql
-- On EU-West secondary
-- Promote to primary
STOP GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group=OFF;

-- Verify promotion
SELECT * FROM performance_schema.replication_group_members;
```

#### Step 3: Update DNS/ProxySQL

```bash
# Update ProxySQL configuration
mysql -u admin -padmin -h proxysql -P 6032 <<EOF
UPDATE mysql_servers SET hostgroup_id=0 WHERE hostname LIKE 'mysql-eu-west%';
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
EOF

# Update DNS records (if using DNS failover)
# Point mysql-primary.banking.com to EU-West
```

#### Step 4: Verify Data Consistency

```sql
-- Check replication lag
SELECT
  CHANNEL_NAME,
  SECONDS_BEHIND_MASTER
FROM performance_schema.replication_connection_status;

-- Verify data integrity
SELECT COUNT(*) FROM accounts;
SELECT MAX(transaction_id) FROM transactions;
```

#### Step 5: Monitor and Document

- Document failover time
- Monitor application performance
- Verify all services are operational

**Recovery Time:** <60 seconds  
**Data Loss:** Zero (synchronous replication)

---

## Scenario 2: Logical Corruption

### Symptoms

- Data inconsistencies detected
- Application errors related to data
- Integrity checks failing

### Recovery Procedure

#### Step 1: Identify Corruption Point

```sql
-- Check binary logs for corruption
SHOW BINARY LOGS;

-- Identify last known good state
SELECT MAX(transaction_id) FROM transactions WHERE status = 'COMPLETED';

-- Check for corrupted tables
CHECK TABLE accounts, transactions, customers;
```

#### Step 2: Stop Replication

```sql
-- Stop replication to prevent spread
STOP SLAVE;
STOP GROUP_REPLICATION;
```

#### Step 3: Restore from Backup

```bash
# Identify backup before corruption
ls -lth /backups/mysql/

# Restore database
mysql -u root -p < /backups/mysql/mysql-backup-20260130-120000.sql

# Or restore specific tables
mysql -u root -p banking < /backups/mysql/accounts-backup.sql
```

#### Step 4: Replay Binary Logs

```bash
# Replay binary logs up to corruption point
mysqlbinlog \
  --start-datetime="2026-01-30 12:00:00" \
  --stop-datetime="2026-01-30 12:05:00" \
  /var/lib/mysql/mysql-bin.000001 | mysql -u root -p
```

#### Step 5: Verify Data Integrity

```sql
-- Run integrity checks
CHECK TABLE accounts, transactions, customers;

-- Verify record counts
SELECT COUNT(*) FROM accounts;
SELECT COUNT(*) FROM transactions;

-- Cross-validate with application
```

#### Step 6: Resume Replication

```sql
-- Resume replication
START GROUP_REPLICATION;

-- Monitor replication lag
SELECT SECONDS_BEHIND_MASTER FROM performance_schema.replication_connection_status;
```

**Recovery Time:** <15 minutes  
**Data Loss:** Maximum 5 minutes (RPO = 5 min)

---

## Scenario 3: Security Breach

### Symptoms

- Unauthorized access detected
- Suspicious queries in audit logs
- Data exfiltration alerts

### Recovery Procedure

#### Step 1: Immediate Isolation

```bash
# Isolate affected systems
iptables -A INPUT -s <suspicious_ip> -j DROP

# Disable compromised accounts
mysql -u root -p <<EOF
DROP USER 'compromised_user'@'%';
FLUSH PRIVILEGES;
EOF
```

#### Step 2: Forensic Data Capture

```bash
# Capture system state
ps aux > /forensics/process-list-$(date +%Y%m%d-%H%M%S).txt
netstat -tulpn > /forensics/network-connections-$(date +%Y%m%d-%H%M%S).txt

# Capture database state
mysqldump --all-databases > /forensics/mysql-dump-$(date +%Y%m%d-%H%M%S).sql

# Capture binary logs
cp /var/lib/mysql/mysql-bin.* /forensics/
```

#### Step 3: Golden Image Restoration

```bash
# Stop MySQL
systemctl stop mysql

# Restore from golden image
rsync -av /golden-images/mysql/ /var/lib/mysql/

# Restore configuration
cp /golden-images/mysql/my.cnf /etc/mysql/my.cnf

# Start MySQL
systemctl start mysql
```

#### Step 4: Audit Trail Preservation

```sql
-- Export audit logs
SELECT * FROM audit_log
WHERE created_at >= '2026-01-30 00:00:00'
INTO OUTFILE '/forensics/audit-log-export.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';
```

#### Step 5: Credential Rotation

```bash
# Rotate all database passwords
mysql -u root -p <<EOF
ALTER USER 'app_user'@'%' IDENTIFIED BY '$(openssl rand -base64 32)';
ALTER USER 'monitoring_user'@'%' IDENTIFIED BY '$(openssl rand -base64 32)';
FLUSH PRIVILEGES;
EOF

# Update application configuration
# Update connection strings in configuration management
```

#### Step 6: Security Patch Deployment

```bash
# Apply security patches
apt-get update
apt-get install mysql-server-8.0

# Verify patches
mysql --version
```

#### Step 7: Post-Incident Review

- Document incident timeline
- Identify root cause
- Implement preventive measures
- Update security policies

**Recovery Time:** <2 hours  
**Data Loss:** Zero (golden image restoration)

---

## Scenario 4: Disk Failure

### Symptoms

- Disk I/O errors in logs
- Database crashes
- Data directory corruption

### Recovery Procedure

#### Step 1: Assess Damage

```bash
# Check disk health
smartctl -a /dev/sdb

# Check filesystem
fsck -n /var/lib/mysql

# Check MySQL error log
tail -100 /var/log/mysql/error.log
```

#### Step 2: Stop MySQL

```bash
systemctl stop mysql
```

#### Step 3: Replace Failed Disk

```bash
# If using RAID, rebuild array
mdadm --manage /dev/md0 --add /dev/sdc

# If single disk, replace hardware
# Mount new disk
mount /dev/sdc /mnt/new-disk
```

#### Step 4: Restore from Backup

```bash
# Restore data directory
rsync -av /backups/mysql/data/ /var/lib/mysql/

# Restore binary logs
rsync -av /backups/mysql/binlogs/ /var/lib/mysql/
```

#### Step 5: Verify and Start

```bash
# Verify data integrity
mysqlcheck --all-databases --check

# Start MySQL
systemctl start mysql

# Verify replication
SELECT * FROM performance_schema.replication_group_members;
```

**Recovery Time:** <30 minutes  
**Data Loss:** Zero (backup restoration)

---

## Backup Procedures

### Daily Backups

```bash
#!/bin/bash
# daily-backup.sh

BACKUP_DIR="/backups/mysql/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Full backup
mysqldump \
  --all-databases \
  --single-transaction \
  --master-data=2 \
  --flush-logs \
  --routines \
  --triggers \
  | gzip > $BACKUP_DIR/full-backup.sql.gz

# Encrypt backup
openssl enc -aes-256-gcm -salt -pbkdf2 \
  -kfile /etc/backup-keys/mysql-backup.key \
  -in $BACKUP_DIR/full-backup.sql.gz \
  -out $BACKUP_DIR/full-backup.sql.gz.enc

# Upload to S3
aws s3 cp $BACKUP_DIR/full-backup.sql.gz.enc \
  s3://backups-banking/mysql/$(date +%Y%m%d)/

# Cleanup old backups (keep 30 days)
find /backups/mysql -type f -mtime +30 -delete
```

### Point-in-Time Recovery Setup

```sql
-- Enable binary logging
SET GLOBAL log_bin = ON;
SET GLOBAL binlog_format = 'ROW';
SET GLOBAL expire_logs_days = 7;

-- Create backup marker
FLUSH LOGS;
```

## Testing Recovery Procedures

### Monthly DR Drill

1. **Schedule**: First Saturday of each month
2. **Scope**: Test one recovery scenario
3. **Documentation**: Document results and improvements
4. **Review**: Review with team and update procedures

### Recovery Time Objectives (RTO)

| Scenario           | RTO | RPO |
| ------------------ | --- | --- |
| Regional Outage    | 60s | 0s  |
| Logical Corruption | 15m | 5m  |
| Security Breach    | 2h  | 0s  |
| Disk Failure       | 30m | 0s  |

## Monitoring and Alerts

### Key Metrics

- Backup success/failure
- Backup size and duration
- Replication lag
- Disk space usage
- Binary log size

### Alerts

- Backup failure
- Replication lag > 5 seconds
- Disk space < 20%
- Binary log size > 10GB
