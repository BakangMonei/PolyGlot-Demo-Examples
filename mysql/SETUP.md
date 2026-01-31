# MySQL 8.0 Enterprise Setup Guide

## Overview

This guide provides step-by-step instructions for deploying MySQL 8.0 Enterprise Edition as the System of Record for the global banking platform.

## Prerequisites

- MySQL 8.0 Enterprise Edition
- Minimum 3 nodes per region (9 total nodes)
- Network connectivity between regions
- SSL certificates for TLS 1.3
- Key management system (AWS KMS or equivalent)

## Installation

### Step 1: Install MySQL 8.0 Enterprise

```bash
# Download MySQL Enterprise Server
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-enterprise-server-8.0.x-linux-glibc2.28-x86_64.tar.gz

# Extract and install
tar -xzf mysql-enterprise-server-8.0.x-linux-glibc2.28-x86_64.tar.gz
cd mysql-enterprise-server-8.0.x-linux-glibc2.28-x86_64
sudo ./bin/mysqld --initialize-insecure --datadir=/var/lib/mysql
```

### Step 2: Configure MySQL

Edit `/etc/mysql/my.cnf`:

```ini
[mysqld]
# Basic Configuration
port = 3306
datadir = /var/lib/mysql
socket = /var/run/mysqld/mysqld.sock
pid-file = /var/run/mysqld/mysqld.pid

# Performance Tuning
innodb_buffer_pool_size = 128G
innodb_buffer_pool_instances = 16
innodb_log_file_size = 4G
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
max_connections = 1000
thread_cache_size = 100
table_open_cache = 4000

# Group Replication
server_id = 1  # Unique per node
gtid_mode = ON
enforce_gtid_consistency = ON
binlog_checksum = NONE
log_bin = mysql-bin
log_slave_updates = ON
binlog_format = ROW
master_info_repository = TABLE
relay_log_info_repository = TABLE
transaction_write_set_extraction = XXHASH64
loose-group_replication_group_name = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
loose-group_replication_start_on_boot = OFF
loose-group_replication_local_address = "node1:33061"
loose-group_replication_group_seeds = "node1:33061,node2:33061,node3:33061"
loose-group_replication_bootstrap_group = OFF
loose-group_replication_consistency = AFTER

# Semi-Synchronous Replication
plugin_load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
rpl_semi_sync_master_enabled = 1
rpl_semi_sync_slave_enabled = 1
rpl_semi_sync_master_timeout = 1000

# SSL/TLS Configuration
ssl-ca = /etc/mysql/ca.pem
ssl-cert = /etc/mysql/server-cert.pem
ssl-key = /etc/mysql/server-key.pem
require_secure_transport = ON
tls_version = TLSv1.3

# Transparent Data Encryption
early-plugin-load = keyring_file=keyring_file.so
keyring_file_data = /var/lib/mysql-keyring/keyring

# Resource Groups
resource_groups = ON

# Query Cache (disabled for MySQL 8.0)
query_cache_type = 0
query_cache_size = 0

# Slow Query Log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 0.1

# Error Log
log_error = /var/log/mysql/error.log
log_error_verbosity = 2

# Binary Log
expire_logs_days = 7
max_binlog_size = 1G
binlog_expire_logs_seconds = 604800

# Character Set
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci

# Time Zone
default_time_zone = '+00:00'
```

### Step 3: Set Up Group Replication

```sql
-- On each node, create replication user
CREATE USER 'repl'@'%' IDENTIFIED BY 'secure_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

-- Install Group Replication plugin
INSTALL PLUGIN group_replication SONAME 'group_replication.so';

-- On primary node, bootstrap the group
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group=OFF;

-- On secondary nodes, join the group
START GROUP_REPLICATION;

-- Verify group status
SELECT * FROM performance_schema.replication_group_members;
```

### Step 4: Configure Multi-Source Replication

```sql
-- Configure channel for US-East to EU-West
CHANGE MASTER TO
  MASTER_HOST='us-east-primary',
  MASTER_USER='repl',
  MASTER_PASSWORD='secure_password',
  MASTER_AUTO_POSITION=1,
  MASTER_SSL=1,
  MASTER_SSL_CA='/etc/mysql/ca.pem',
  MASTER_SSL_CERT='/etc/mysql/client-cert.pem',
  MASTER_SSL_KEY='/etc/mysql/client-key.pem'
FOR CHANNEL 'us-east-to-eu-west';

START SLAVE FOR CHANNEL 'us-east-to-eu-west';

-- Configure channel for US-East to AP-Southeast
CHANGE MASTER TO
  MASTER_HOST='us-east-primary',
  MASTER_USER='repl',
  MASTER_PASSWORD='secure_password',
  MASTER_AUTO_POSITION=1,
  MASTER_SSL=1
FOR CHANNEL 'us-east-to-ap-southeast';

START SLAVE FOR CHANNEL 'us-east-to-ap-southeast';

-- Monitor replication lag
SELECT
  CHANNEL_NAME,
  MASTER_LOG_FILE,
  READ_MASTER_LOG_POS,
  RELAY_LOG_FILE,
  RELAY_LOG_POS,
  RELAY_MASTER_LOG_FILE,
  EXEC_MASTER_LOG_POS,
  SLAVE_IO_RUNNING,
  SLAVE_SQL_RUNNING,
  SECONDS_BEHIND_MASTER
FROM performance_schema.replication_connection_status;
```

### Step 5: Set Up Vitess/ProxySQL Sharding

#### Install ProxySQL

```bash
# Install ProxySQL
wget https://github.com/sysown/proxysql/releases/download/v2.5.5/proxysql_2.5.5-ubuntu20_amd64.deb
sudo dpkg -i proxysql_2.5.5-ubuntu20_amd64.deb
sudo systemctl start proxysql
```

#### Configure ProxySQL

```sql
-- Connect to ProxySQL admin interface
mysql -u admin -padmin -h 127.0.0.1 -P 6032

-- Add MySQL servers
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections) VALUES
(0, 'mysql-shard-1', 3306, 1000, 1000),
(1, 'mysql-shard-2', 3306, 1000, 1000),
(2, 'mysql-shard-3', 3306, 1000, 1000);
-- ... add all 256 shards

-- Configure sharding rules
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) VALUES
(1, 1, '^SELECT.*WHERE customer_id\s*=\s*(\d+)',
  (HASH(SUBSTRING_INDEX(SUBSTRING_INDEX(match_pattern, '=', -1), ' ', 1)) % 256), 1);

-- Load configuration
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;
```

### Step 6: Enable Row-Level Security

```sql
-- Create policy table
CREATE TABLE user_permissions (
  user_id VARCHAR(100) PRIMARY KEY,
  customer_ids JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create RLS policy function
DELIMITER //
CREATE FUNCTION check_customer_access(customer_id BIGINT, user_id VARCHAR(100))
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE has_access BOOLEAN DEFAULT FALSE;
  SELECT JSON_CONTAINS(customer_ids, CAST(customer_id AS JSON))
    INTO has_access
  FROM user_permissions
  WHERE user_id = check_customer_access.user_id;
  RETURN has_access;
END//
DELIMITER ;

-- Enable RLS on accounts table
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_access_policy ON accounts
  FOR ALL
  USING (check_customer_access(customer_id, CURRENT_USER()));
```

### Step 7: Configure MySQL HeatWave

```sql
-- Install HeatWave plugin
INSTALL PLUGIN heatwave SONAME 'ha_heatwave.so';

-- Load data into HeatWave
ALTER TABLE transactions SECONDARY_LOAD;

-- Query HeatWave
SELECT /*+ SET_VAR(use_secondary_engine=ON) */
  customer_id,
  SUM(amount) as total_amount,
  COUNT(*) as transaction_count
FROM transactions
WHERE transaction_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY customer_id;
```

### Step 8: Set Up Resource Groups

```sql
-- Create resource groups
CREATE RESOURCE GROUP critical_operations
  TYPE = USER
  VCPU = 0-3
  THREAD_PRIORITY = 19;

CREATE RESOURCE GROUP standard_operations
  TYPE = USER
  VCPU = 4-7
  THREAD_PRIORITY = 10;

CREATE RESOURCE GROUP analytics_operations
  TYPE = USER
  VCPU = 8-15
  THREAD_PRIORITY = 5;

-- Assign users to resource groups
ALTER USER 'critical_app'@'%' RESOURCE GROUP critical_operations;
ALTER USER 'standard_app'@'%' RESOURCE GROUP standard_operations;
ALTER USER 'analytics_user'@'%' RESOURCE GROUP analytics_operations;
```

### Step 9: Configure Transparent Data Encryption

```sql
-- Install keyring plugin
INSTALL PLUGIN keyring_file SONAME 'keyring_file.so';

-- Create encrypted tablespace
CREATE TABLESPACE banking_encrypted
  ADD DATAFILE 'banking_encrypted.ibd'
  ENCRYPTION='Y'
  ENGINE=InnoDB;

-- Create encrypted table
CREATE TABLE sensitive_data (
  id BIGINT PRIMARY KEY,
  data VARCHAR(255)
) TABLESPACE banking_encrypted;

-- Rotate master key (automated via cron)
ALTER INSTANCE ROTATE INNODB MASTER KEY;
```

### Step 10: Set Up Monitoring

```bash
# Install MySQL Exporter for Prometheus
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar -xzf mysqld_exporter-0.15.0.linux-amd64.tar.gz
sudo cp mysqld_exporter /usr/local/bin/

# Create monitoring user
mysql -u root -p <<EOF
CREATE USER 'exporter'@'localhost' IDENTIFIED BY 'exporter_password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configure exporter
cat > /etc/mysql_exporter.cnf <<EOF
[client]
user=exporter
password=exporter_password
EOF

# Start exporter
sudo systemctl enable mysqld_exporter
sudo systemctl start mysqld_exporter
```

## Verification

### Check Group Replication Status

```sql
SELECT * FROM performance_schema.replication_group_members;
SELECT * FROM performance_schema.replication_group_member_stats;
```

### Check Replication Lag

```sql
SELECT
  CHANNEL_NAME,
  SECONDS_BEHIND_MASTER
FROM performance_schema.replication_connection_status;
```

### Check Encryption Status

```sql
SELECT
  SCHEMA_NAME,
  TABLE_NAME,
  CREATE_OPTIONS
FROM information_schema.TABLES
WHERE CREATE_OPTIONS LIKE '%ENCRYPTION%';
```

### Performance Test

```sql
-- Test write performance
SET RESOURCE GROUP critical_operations;
BEGIN;
INSERT INTO transactions (customer_id, amount, transaction_type)
VALUES (123456, 1000.00, 'TRANSFER');
COMMIT;

-- Check query performance
EXPLAIN ANALYZE
SELECT * FROM accounts WHERE customer_id = 123456;
```

## Troubleshooting

### Group Replication Issues

```sql
-- Check group replication status
SELECT * FROM performance_schema.replication_group_members;

-- If node is OFFLINE, check error log
SELECT * FROM performance_schema.replication_group_member_stats;

-- Rejoin node
STOP GROUP_REPLICATION;
START GROUP_REPLICATION;
```

### Replication Lag

```sql
-- Check lag per channel
SELECT CHANNEL_NAME, SECONDS_BEHIND_MASTER
FROM performance_schema.replication_connection_status;

-- If lag is high, check network and disk I/O
SHOW PROCESSLIST;
SHOW ENGINE INNODB STATUS;
```

### Performance Issues

```sql
-- Check slow queries
SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;

-- Check connection pool
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';

-- Check buffer pool
SHOW STATUS LIKE 'Innodb_buffer_pool%';
```

## Maintenance

### Daily Tasks

- Monitor replication lag
- Check error logs
- Review slow query log
- Verify backup completion

### Weekly Tasks

- Analyze query performance
- Optimize indexes
- Review resource group usage
- Check disk space

### Monthly Tasks

- Rotate encryption keys
- Review security audit logs
- Capacity planning review
- Performance baseline comparison

## Backup and Recovery

See [Disaster Recovery Runbooks](../disaster-recovery/MYSQL_RECOVERY.md) for detailed backup and recovery procedures.
