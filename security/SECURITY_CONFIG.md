# Security and Compliance Configuration

## Multi-Layer Security Architecture

## Overview

This document outlines the comprehensive security configuration for the hybrid database system, covering data at rest, data in transit, access control, and regulatory compliance.

## Layer 1: Data at Rest Encryption

### MySQL Transparent Data Encryption (TDE)

```sql
-- Install keyring plugin
INSTALL PLUGIN keyring_file SONAME 'keyring_file.so';

-- Configure keyring
SET GLOBAL keyring_file_data = '/var/lib/mysql-keyring/keyring';

-- Create encrypted tablespace
CREATE TABLESPACE banking_encrypted
  ADD DATAFILE 'banking_encrypted.ibd'
  ENCRYPTION='Y'
  ENGINE=InnoDB;

-- Create encrypted table
CREATE TABLE sensitive_customer_data (
  customer_id BIGINT PRIMARY KEY,
  ssn_encrypted VARBINARY(256),
  account_numbers VARBINARY(512)
) TABLESPACE banking_encrypted;

-- Master key rotation (automated every 90 days)
-- Script: rotate-mysql-keys.sh
ALTER INSTANCE ROTATE INNODB MASTER KEY;
```

### MongoDB Encrypted Storage Engine

```yaml
# mongod.conf
storage:
  wiredTiger:
    engineConfig:
      encryptionKeyFile: /etc/mongodb/encryption-key
    collectionConfig:
      blockCompressor: snappy
```

### Backup Encryption

```bash
#!/bin/bash
# encrypt-backup.sh

# MySQL backup encryption
mysqldump --all-databases | \
  openssl enc -aes-256-gcm -salt -pbkdf2 \
  -kfile /etc/backup-keys/mysql-backup.key \
  -out /backups/mysql-encrypted-$(date +%Y%m%d).sql.enc

# MongoDB backup encryption
mongodump --archive | \
  openssl enc -aes-256-gcm -salt -pbkdf2 \
  -kfile /etc/backup-keys/mongodb-backup.key \
  -out /backups/mongodb-encrypted-$(date +%Y%m%d).archive.enc
```

## Layer 2: Data in Transit Encryption

### TLS 1.3 Configuration

#### MySQL TLS Configuration

```ini
# my.cnf
[mysqld]
ssl-ca=/etc/mysql/ca.pem
ssl-cert=/etc/mysql/server-cert.pem
ssl-key=/etc/mysql/server-key.pem
require_secure_transport=ON
tls_version=TLSv1.3
ssl_cipher='TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256'

[client]
ssl-ca=/etc/mysql/ca.pem
ssl-cert=/etc/mysql/client-cert.pem
ssl-key=/etc/mysql/client-key.pem
ssl-mode=REQUIRED
```

#### MongoDB TLS Configuration

```yaml
# mongod.conf
net:
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/mongodb/ssl/server.pem
    CAFile: /etc/mongodb/ssl/ca.pem
    allowConnectionsWithoutCertificates: false
    allowInvalidCertificates: false
    disabledProtocols: TLS1_0,TLS1_1,TLS1_2
    allowConnectionsWithoutCertificates: false
```

### Certificate Pinning

```javascript
// certificate-pinning.js
const tls = require("tls");
const crypto = require("crypto");

const PINNED_CERTIFICATES = {
  "mysql.banking.com": "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  "mongodb.banking.com": "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
};

function verifyCertificate(hostname, cert) {
  const fingerprint = crypto.createHash("sha256").update(cert).digest("base64");

  const pinned = PINNED_CERTIFICATES[hostname];

  if (pinned && fingerprint !== pinned) {
    throw new Error(`Certificate pinning failed for ${hostname}`);
  }

  return true;
}
```

## Layer 3: Access Control

### MySQL RBAC with ABAC

```sql
-- Create roles
CREATE ROLE 'fraud_analyst';
CREATE ROLE 'customer_service';
CREATE ROLE 'data_analyst';

-- Grant permissions with ABAC
-- Fraud analyst can only access flagged transactions
CREATE POLICY fraud_analyst_policy ON transactions
  FOR SELECT
  USING (
    fraud_score > 0.7 OR
    status = 'FLAGGED' OR
    customer_id IN (
      SELECT customer_id FROM flagged_customers
    )
  );

-- Customer service can only access assigned customers
CREATE POLICY customer_service_policy ON accounts
  FOR ALL
  USING (
    customer_id IN (
      SELECT customer_id FROM user_assigned_customers
      WHERE user_id = CURRENT_USER()
    )
  );

-- Assign roles
GRANT 'fraud_analyst' TO 'analyst@banking.com';
GRANT 'customer_service' TO 'service@banking.com';

-- Enable RLS
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
```

### MongoDB SCRAM-SHA-256 with LDAP

```javascript
// mongod.conf
security:
  authorization: enabled
  authenticationMechanisms: SCRAM-SHA-256
  ldap:
    servers: ldap://ldap.banking.com
    bindMethod: simple
    bindQueryUser: "cn=admin,dc=banking,dc=com"
    bindQueryPassword: "secure_password"
    userToDNMapping: '{"match": "(.+)", "ldapQuery": "cn={0},ou=users,dc=banking,dc=com"}'

// Create roles
use admin
db.createRole({
  role: "fraudAnalyst",
  privileges: [
    {
      resource: { db: "banking", collection: "transactions" },
      actions: [ "find", "aggregate" ]
    }
  ],
  roles: []
})

// Assign role
db.grantRolesToUser("analyst@banking.com", ["fraudAnalyst"])
```

### Just-in-Time Access

```javascript
// jit-access.js
const mongodb = require("./mongodb-client");
const mysql = require("./mysql-client");

class JustInTimeAccess {
  constructor() {
    this.accessDuration = 15 * 60 * 1000; // 15 minutes
  }

  async grantTemporaryAccess(userId, resource, permission) {
    const accessToken = require("crypto").randomBytes(32).toString("hex");
    const expiresAt = new Date(Date.now() + this.accessDuration);

    // Store access grant
    await mongodb.collection("jit_access_grants").insertOne({
      access_token: accessToken,
      user_id: userId,
      resource,
      permission,
      granted_at: new Date(),
      expires_at: expiresAt,
      status: "ACTIVE",
    });

    // Schedule revocation
    setTimeout(async () => {
      await this.revokeAccess(accessToken);
    }, this.accessDuration);

    return accessToken;
  }

  async validateAccess(accessToken, resource, permission) {
    const grant = await mongodb.collection("jit_access_grants").findOne({
      access_token: accessToken,
      resource,
      permission,
      status: "ACTIVE",
      expires_at: { $gt: new Date() },
    });

    if (!grant) {
      throw new Error("Access denied or expired");
    }

    return grant;
  }

  async revokeAccess(accessToken) {
    await mongodb
      .collection("jit_access_grants")
      .updateOne(
        { access_token: accessToken },
        { $set: { status: "REVOKED", revoked_at: new Date() } }
      );
  }
}

module.exports = JustInTimeAccess;
```

## Compliance Requirements

### PCI-DSS Compliance

```sql
-- PCI-DSS: Mask card numbers in logs
SET GLOBAL log_bin_trust_function_creators = 1;

DELIMITER //
CREATE FUNCTION mask_card_number(card_number VARCHAR(19))
RETURNS VARCHAR(19)
DETERMINISTIC
BEGIN
  IF LENGTH(card_number) >= 4 THEN
    RETURN CONCAT('****-****-****-', RIGHT(card_number, 4));
  END IF;
  RETURN '****-****-****-****';
END//
DELIMITER ;

-- PCI-DSS: Audit all card data access
CREATE TABLE pci_audit_log (
  audit_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id VARCHAR(100),
  action VARCHAR(50),
  card_number_masked VARCHAR(19),
  accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_accessed_at (accessed_at)
);
```

### GDPR/CCPA: Right to Erasure

```javascript
// gdpr-erasure.js
const mysql = require("./mysql-client");
const mongodb = require("./mongodb-client");
const crypto = require("crypto");

class GDPRErasure {
  async eraseCustomerData(customerId) {
    // Cryptographic shredding: Replace with hash
    const erasureHash = crypto
      .createHash("sha256")
      .update(`${customerId}-${Date.now()}`)
      .digest("hex");

    // Erase from MySQL
    await mysql.query(
      `UPDATE customers 
       SET first_name = ?, 
           last_name = ?,
           email = ?,
           ssn_hash = ?,
           status = 'ERASED'
       WHERE customer_id = ?`,
      [
        "ERASED",
        "ERASED",
        `erased-${erasureHash}@erased.com`,
        erasureHash,
        customerId,
      ]
    );

    // Erase from MongoDB
    await mongodb.collection("customers").updateOne(
      { customer_id: customerId },
      {
        $set: {
          "personal_info.name.first": "ERASED",
          "personal_info.name.last": "ERASED",
          "personal_info.email": `erased-${erasureHash}@erased.com`,
          "personal_info.ssn": null,
          status: "ERASED",
          erased_at: new Date(),
        },
      }
    );

    // Log erasure
    await mongodb.collection("gdpr_erasure_log").insertOne({
      customer_id: customerId,
      erasure_hash: erasureHash,
      erased_at: new Date(),
      requested_by: "system",
    });
  }

  async exportCustomerData(customerId) {
    // GDPR/CCPA: Right to data portability
    const mysqlData = await mysql.query(
      `SELECT * FROM customers WHERE customer_id = ?`,
      [customerId]
    );

    const mongoData = await mongodb
      .collection("customers")
      .findOne({ customer_id: customerId });

    return {
      mysql: mysqlData[0],
      mongodb: mongoData,
      exported_at: new Date(),
    };
  }
}

module.exports = GDPRErasure;
```

### SOC 2 Type II: Automated Evidence Collection

```javascript
// soc2-evidence.js
const mongodb = require("./mongodb-client");
const mysql = require("./mysql-client");

class SOC2Evidence {
  async collectAccessControlEvidence() {
    // Collect access control logs
    const accessLogs = await mysql.query(
      `SELECT user_id, action, resource, timestamp 
       FROM access_log 
       WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 1 DAY)
       ORDER BY timestamp DESC`
    );

    return {
      type: "access_control",
      period: "daily",
      records: accessLogs,
      collected_at: new Date(),
    };
  }

  async collectEncryptionEvidence() {
    // Verify encryption is enabled
    const mysqlEncryption = await mysql.query(
      `SELECT TABLE_SCHEMA, TABLE_NAME, CREATE_OPTIONS 
       FROM information_schema.TABLES 
       WHERE CREATE_OPTIONS LIKE '%ENCRYPTION%'`
    );

    const mongoEncryption = await mongodb.admin().command({
      getParameter: 1,
      encryptionOptions: 1,
    });

    return {
      type: "encryption",
      mysql: {
        encrypted_tables: mysqlEncryption.length,
        tables: mysqlEncryption,
      },
      mongodb: {
        encryption_enabled: mongoEncryption.encryptionOptions !== null,
      },
      collected_at: new Date(),
    };
  }

  async collectBackupEvidence() {
    // Verify backups are encrypted and tested
    const backups = await mongodb
      .collection("backup_logs")
      .find({
        backup_date: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
      })
      .toArray();

    return {
      type: "backup",
      period: "weekly",
      backups: backups.map((b) => ({
        date: b.backup_date,
        encrypted: b.encrypted,
        tested: b.restore_tested,
        size: b.size,
      })),
      collected_at: new Date(),
    };
  }

  async generateSOC2Report() {
    const evidence = {
      access_control: await this.collectAccessControlEvidence(),
      encryption: await this.collectEncryptionEvidence(),
      backup: await this.collectBackupEvidence(),
      generated_at: new Date(),
    };

    // Store evidence
    await mongodb.collection("soc2_evidence").insertOne(evidence);

    return evidence;
  }
}

module.exports = SOC2Evidence;
```

### FedRAMP: Continuous Monitoring

```javascript
// fedramp-monitoring.js
const mongodb = require("./mongodb-client");
const mysql = require("./mysql-client");

class FedRAMPMonitoring {
  async monitorSecurityControls() {
    const controls = {
      // CC-1: Access Control
      access_control: await this.checkAccessControl(),

      // SC-7: Boundary Protection
      boundary_protection: await this.checkBoundaryProtection(),

      // SI-3: Malicious Code Protection
      malicious_code_protection: await this.checkMaliciousCodeProtection(),

      // AU-2: Audit Events
      audit_events: await this.checkAuditEvents(),

      monitored_at: new Date(),
    };

    // Store monitoring results
    await mongodb.collection("fedramp_monitoring").insertOne(controls);

    // Alert on failures
    for (const [control, status] of Object.entries(controls)) {
      if (control !== "monitored_at" && !status.compliant) {
        await this.alertNonCompliance(control, status);
      }
    }

    return controls;
  }

  async checkAccessControl() {
    // Verify MFA is enabled
    const mfaEnabled = await this.verifyMFA();

    // Verify least privilege
    const leastPrivilege = await this.verifyLeastPrivilege();

    return {
      compliant: mfaEnabled && leastPrivilege,
      mfa_enabled: mfaEnabled,
      least_privilege: leastPrivilege,
    };
  }

  async checkBoundaryProtection() {
    // Verify firewall rules
    const firewallRules = await this.getFirewallRules();

    // Verify network segmentation
    const networkSegmentation = await this.verifyNetworkSegmentation();

    return {
      compliant: firewallRules.valid && networkSegmentation.valid,
      firewall_rules: firewallRules,
      network_segmentation: networkSegmentation,
    };
  }

  async checkMaliciousCodeProtection() {
    // Verify antivirus is running
    const antivirusStatus = await this.checkAntivirus();

    // Verify database security patches
    const securityPatches = await this.checkSecurityPatches();

    return {
      compliant: antivirusStatus.active && securityPatches.current,
      antivirus: antivirusStatus,
      security_patches: securityPatches,
    };
  }

  async checkAuditEvents() {
    // Verify audit logging is enabled
    const auditLogging = await this.verifyAuditLogging();

    // Verify log retention
    const logRetention = await this.verifyLogRetention();

    return {
      compliant: auditLogging.enabled && logRetention.compliant,
      audit_logging: auditLogging,
      log_retention: logRetention,
    };
  }

  async alertNonCompliance(control, status) {
    // Send alert to security team
    console.error(`[FedRAMP] Control ${control} non-compliant:`, status);
  }
}

module.exports = FedRAMPMonitoring;
```

## Security Monitoring

### Key Metrics

- Failed authentication attempts
- Privilege escalation attempts
- Encryption key rotation status
- Access control violations
- Compliance check results

### Alerts

- Failed authentication > 10 per minute
- Privilege escalation detected
- Encryption key rotation overdue
- Compliance check failures
- Unauthorized access attempts

## Best Practices

1. **Defense in Depth**: Multiple layers of security
2. **Least Privilege**: Grant minimum required permissions
3. **Encryption Everywhere**: Encrypt data at rest and in transit
4. **Regular Audits**: Continuous security monitoring
5. **Key Rotation**: Rotate encryption keys regularly
6. **Access Reviews**: Regular access control reviews
7. **Incident Response**: Automated incident detection and response
