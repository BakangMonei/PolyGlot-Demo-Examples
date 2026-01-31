# Data Mesh Pattern Implementation

## Federated Data Governance with Domain Ownership

## Overview

Data Mesh implements a decentralized data architecture where each banking domain (payments, loans, cards) owns and serves its data as a product, with federated governance ensuring consistency and compliance.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Payments   │     │    Loans    │     │    Cards    │
│ Data Product│     │ Data Product│     │ Data Product│
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                  ┌────────▼────────┐
                  │ Federated       │
                  │ Governance      │
                  │ Layer           │
                  └────────┬────────┘
                           │
                  ┌────────▼────────┐
                  │ Data Contracts  │
                  │ & Quality      │
                  │ Validation     │
                  └────────────────┘
```

## Implementation

### Data Product Definition

```yaml
# payments-data-product.yaml
apiVersion: datamesh.banking.com/v1
kind: DataProduct
metadata:
  name: payments-data-product
  domain: payments
  version: "1.0.0"
  owner: payments-team@banking.com
spec:
  # Data sources
  sources:
    mysql:
      database: banking
      tables:
        - payments
        - payment_methods
        - payment_transactions
    mongodb:
      database: banking
      collections:
        - payment_analytics
        - payment_events

  # Data contracts
  contracts:
    - name: payment-schema
      version: "1.0.0"
      schema: schemas/payment-schema.json
      quality:
        freshness: 1s
        completeness: 100%
        accuracy: 99.999%

    - name: payment-analytics-schema
      version: "1.0.0"
      schema: schemas/payment-analytics-schema.json
      quality:
        freshness: 5s
        completeness: 100%
        accuracy: 99.9%

  # Access control
  access:
    - role: payments-team
      permissions: [read, write, admin]
    - role: fraud-team
      permissions: [read]
    - role: analytics-team
      permissions: [read]

  # APIs
  apis:
    rest:
      baseUrl: https://api.banking.com/v1/payments
      endpoints:
        - /payments/{payment_id}
        - /payments/{payment_id}/status
        - /payments/search
    graphql:
      schema: schemas/payments.graphql
    kafka:
      topics:
        - payments.created
        - payments.updated
        - payments.completed

  # Lineage
  lineage:
    upstream:
      - source: customer-service
        type: api
      - source: account-service
        type: database
    downstream:
      - consumer: fraud-detection-service
        type: kafka
      - consumer: analytics-platform
        type: api
```

### Data Contract Schema

```json
// payment-schema.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": [
    "payment_id",
    "customer_id",
    "amount",
    "currency",
    "status",
    "created_at"
  ],
  "properties": {
    "payment_id": {
      "type": "string",
      "format": "uuid",
      "description": "Unique payment identifier"
    },
    "customer_id": {
      "type": "integer",
      "minimum": 1,
      "description": "Customer identifier"
    },
    "amount": {
      "type": "number",
      "minimum": 0,
      "multipleOf": 0.01,
      "description": "Payment amount"
    },
    "currency": {
      "type": "string",
      "pattern": "^[A-Z]{3}$",
      "description": "ISO 4217 currency code"
    },
    "status": {
      "type": "string",
      "enum": ["PENDING", "PROCESSING", "COMPLETED", "FAILED", "CANCELLED"],
      "description": "Payment status"
    },
    "payment_method": {
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["CARD", "ACH", "WIRE", "CHECK"]
        },
        "last_four": {
          "type": "string",
          "pattern": "^[0-9]{4}$"
        }
      }
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "Payment creation timestamp"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time",
      "description": "Last update timestamp"
    }
  }
}
```

### Data Mesh Governance Service

```javascript
// data-mesh-governance.js
const Ajv = require("ajv");
const ajv = new Ajv({ allErrors: true });
const mysql = require("./mysql-client");
const mongodb = require("./mongodb-client");

class DataMeshGovernance {
  constructor() {
    this.dataProducts = new Map();
    this.contracts = new Map();
    this.loadDataProducts();
  }

  async loadDataProducts() {
    // Load data product definitions
    const products = await mongodb
      .collection("data_products")
      .find({})
      .toArray();

    for (const product of products) {
      this.dataProducts.set(product.metadata.name, product);

      // Load contracts
      for (const contract of product.spec.contracts) {
        const contractSchema = await this.loadContractSchema(contract.schema);
        this.contracts.set(`${product.metadata.name}:${contract.name}`, {
          product: product.metadata.name,
          contract: contract,
          schema: contractSchema,
          validator: ajv.compile(contractSchema),
        });
      }
    }
  }

  async loadContractSchema(schemaPath) {
    // Load schema from file or database
    const fs = require("fs");
    return JSON.parse(fs.readFileSync(schemaPath, "utf8"));
  }

  async validateDataContract(dataProductName, contractName, data) {
    const contractKey = `${dataProductName}:${contractName}`;
    const contract = this.contracts.get(contractKey);

    if (!contract) {
      throw new Error(`Contract not found: ${contractKey}`);
    }

    // Validate schema
    const valid = contract.validator(data);

    if (!valid) {
      const errors = contract.validator.errors;
      throw new Error(`Schema validation failed: ${JSON.stringify(errors)}`);
    }

    // Validate quality metrics
    const qualityMetrics = await this.calculateQualityMetrics(
      dataProductName,
      data
    );
    const qualityContract = contract.contract.quality;

    const qualityIssues = [];

    if (qualityMetrics.freshness > qualityContract.freshness) {
      qualityIssues.push({
        metric: "freshness",
        actual: qualityMetrics.freshness,
        expected: qualityContract.freshness,
      });
    }

    if (qualityMetrics.completeness < qualityContract.completeness) {
      qualityIssues.push({
        metric: "completeness",
        actual: qualityMetrics.completeness,
        expected: qualityContract.completeness,
      });
    }

    if (qualityMetrics.accuracy < qualityContract.accuracy) {
      qualityIssues.push({
        metric: "accuracy",
        actual: qualityMetrics.accuracy,
        expected: qualityContract.accuracy,
      });
    }

    if (qualityIssues.length > 0) {
      await this.alertDataQualityIssue(dataProductName, qualityIssues);
    }

    return {
      valid: true,
      qualityMetrics,
      qualityIssues,
    };
  }

  async calculateQualityMetrics(dataProductName, data) {
    const product = this.dataProducts.get(dataProductName);

    // Calculate freshness (time since last update)
    const freshness = await this.calculateFreshness(dataProductName, data);

    // Calculate completeness (percentage of required fields)
    const completeness = this.calculateCompleteness(
      data,
      product.spec.contracts[0].schema
    );

    // Calculate accuracy (cross-validation with source systems)
    const accuracy = await this.calculateAccuracy(dataProductName, data);

    return {
      freshness,
      completeness,
      accuracy,
      calculated_at: new Date(),
    };
  }

  async calculateFreshness(dataProductName, data) {
    // Compare data timestamp with current time
    if (data.updated_at) {
      const updatedAt = new Date(data.updated_at);
      const now = new Date();
      return (now - updatedAt) / 1000; // seconds
    }
    return 0;
  }

  calculateCompleteness(data, schema) {
    const requiredFields = this.getRequiredFields(schema);
    const presentFields = requiredFields.filter(
      (field) => data[field] !== undefined && data[field] !== null
    );
    return (presentFields.length / requiredFields.length) * 100;
  }

  getRequiredFields(schema) {
    const required = [];

    const traverse = (obj, path = "") => {
      if (obj.required) {
        for (const field of obj.required) {
          required.push(path ? `${path}.${field}` : field);
        }
      }

      if (obj.properties) {
        for (const [key, value] of Object.entries(obj.properties)) {
          traverse(value, path ? `${path}.${key}` : key);
        }
      }
    };

    traverse(schema);
    return required;
  }

  async calculateAccuracy(dataProductName, data) {
    // Cross-validate with source systems
    const product = this.dataProducts.get(dataProductName);

    // Example: Validate payment amount matches source
    if (dataProductName === "payments-data-product" && data.payment_id) {
      const sourcePayment = await mysql.query(
        `SELECT amount FROM payments WHERE payment_id = ?`,
        [data.payment_id]
      );

      if (sourcePayment.length > 0) {
        const sourceAmount = parseFloat(sourcePayment[0].amount);
        const dataAmount = parseFloat(data.amount);

        if (Math.abs(sourceAmount - dataAmount) < 0.01) {
          return 100;
        } else {
          return 0;
        }
      }
    }

    return 100; // Default to 100% if validation not applicable
  }

  async trackDataLineage(source, destination, transformation) {
    const lineageRecord = {
      lineage_id: require("uuid").v4(),
      source: {
        system: source.system,
        table: source.table,
        record_id: source.record_id,
        timestamp: new Date(),
      },
      destination: {
        system: destination.system,
        collection: destination.collection,
        document_id: destination.document_id,
        timestamp: new Date(),
      },
      transformation: transformation,
      created_at: new Date(),
    };

    await mongodb.collection("data_lineage").insertOne(lineageRecord);

    return lineageRecord.lineage_id;
  }

  async getDataLineage(dataProductName, recordId) {
    // Get upstream lineage
    const upstream = await mongodb
      .collection("data_lineage")
      .find({
        "destination.collection": dataProductName,
        "destination.document_id": recordId,
      })
      .toArray();

    // Get downstream lineage
    const downstream = await mongodb
      .collection("data_lineage")
      .find({
        "source.table": dataProductName,
        "source.record_id": recordId,
      })
      .toArray();

    return {
      upstream,
      downstream,
    };
  }

  async alertDataQualityIssue(dataProductName, issues) {
    const alert = {
      severity: "warning",
      data_product: dataProductName,
      issues,
      timestamp: new Date(),
    };

    // Send to monitoring system
    console.error("[DataMesh] Quality issue detected:", alert);

    // Store in database
    await mongodb.collection("data_quality_alerts").insertOne(alert);
  }

  async checkAccess(userId, dataProductName, permission) {
    const product = this.dataProducts.get(dataProductName);

    if (!product) {
      return false;
    }

    // Get user roles
    const userRoles = await this.getUserRoles(userId);

    // Check if user has required permission
    for (const accessRule of product.spec.access) {
      if (userRoles.includes(accessRule.role)) {
        if (
          accessRule.permissions.includes(permission) ||
          accessRule.permissions.includes("admin")
        ) {
          return true;
        }
      }
    }

    return false;
  }

  async getUserRoles(userId) {
    // Get user roles from identity provider
    // This is a simplified example
    const user = await mongodb.collection("users").findOne({ user_id: userId });
    return user?.roles || [];
  }
}

module.exports = DataMeshGovernance;
```

### Data Product API

```javascript
// data-product-api.js
const express = require("express");
const router = express.Router();
const DataMeshGovernance = require("./data-mesh-governance");
const mysql = require("./mysql-client");
const mongodb = require("./mongodb-client");

const governance = new DataMeshGovernance();

// Middleware to check access
async function checkAccess(req, res, next) {
  const userId = req.user.id;
  const dataProduct = req.params.dataProduct;
  const permission = req.method === "GET" ? "read" : "write";

  const hasAccess = await governance.checkAccess(
    userId,
    dataProduct,
    permission
  );

  if (!hasAccess) {
    return res.status(403).json({ error: "Access denied" });
  }

  next();
}

// Get data product
router.get("/:dataProduct/data/:recordId", checkAccess, async (req, res) => {
  const { dataProduct, recordId } = req.params;
  const product = governance.dataProducts.get(dataProduct);

  if (!product) {
    return res.status(404).json({ error: "Data product not found" });
  }

  // Fetch from appropriate source
  let data;

  if (product.spec.sources.mysql) {
    // Fetch from MySQL
    const table = product.spec.sources.mysql.tables[0];
    const result = await mysql.query(
      `SELECT * FROM ${table} WHERE ${table}_id = ?`,
      [recordId]
    );
    data = result[0];
  } else if (product.spec.sources.mongodb) {
    // Fetch from MongoDB
    const collection = product.spec.sources.mongodb.collections[0];
    data = await mongodb.collection(collection).findOne({ _id: recordId });
  }

  // Validate data contract
  try {
    await governance.validateDataContract(
      dataProduct,
      product.spec.contracts[0].name,
      data
    );
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }

  res.json(data);
});

// Get data lineage
router.get("/:dataProduct/lineage/:recordId", checkAccess, async (req, res) => {
  const { dataProduct, recordId } = req.params;

  const lineage = await governance.getDataLineage(dataProduct, recordId);

  res.json(lineage);
});

// Search data product
router.post("/:dataProduct/search", checkAccess, async (req, res) => {
  const { dataProduct } = req.params;
  const { query, filters } = req.body;

  const product = governance.dataProducts.get(dataProduct);

  if (!product) {
    return res.status(404).json({ error: "Data product not found" });
  }

  // Perform search based on product configuration
  let results;

  if (product.spec.sources.mongodb) {
    // Use MongoDB search
    const collection = product.spec.sources.mongodb.collections[0];
    results = await mongodb
      .collection(collection)
      .aggregate([
        {
          $search: {
            index: `${dataProduct}_search`,
            text: {
              query: query,
              path: { wildcard: "*" },
            },
          },
        },
        {
          $match: filters || {},
        },
      ])
      .toArray();
  }

  res.json(results);
});

module.exports = router;
```

## Monitoring

### Key Metrics

- Data contract validation success rate
- Quality metrics (freshness, completeness, accuracy)
- Data lineage coverage
- API response times
- Access control violations

### Alerts

- Contract validation failures > 1%
- Quality metrics below thresholds
- Data lineage gaps detected
- API errors > 0.1%

## Best Practices

1. **Domain Ownership**: Each domain owns its data product
2. **Data Contracts**: Define clear contracts with quality SLAs
3. **Federated Governance**: Centralized policies, decentralized execution
4. **Lineage Tracking**: Track data flow from source to consumption
5. **Access Control**: Implement role-based access with audit logging
6. **Quality Monitoring**: Continuously monitor quality metrics
7. **Documentation**: Maintain comprehensive data product documentation
