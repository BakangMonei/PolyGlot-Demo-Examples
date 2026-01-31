// MongoDB 6.0+ Customer 360° View Schema
// System of Engagement - Customer Profile and Analytics

// ============================================================================
// CUSTOMER 360° VIEW COLLECTION
// ============================================================================

db.customers.insertOne({
  _id: ObjectId(),
  customer_id: NumberLong(123456789),
  
  // Personal Information (encrypted fields using CSFLE)
  personal_info: {
    name: {
      first: "John",
      middle: "Michael",
      last: "Doe"
    },
    email: "john.doe@example.com",
    phone: {
      primary: "+1-555-0123",
      mobile: "+1-555-0124"
    },
    // Encrypted fields (handled by CSFLE)
    ssn: BinData(6, "..."), // Encrypted via CSFLE
    date_of_birth: BinData(6, "..."), // Encrypted via CSFLE
    drivers_license: BinData(6, "..."), // Encrypted via CSFLE
    address: {
      line1: "123 Main Street",
      line2: "Apt 4B",
      city: "New York",
      state: "NY",
      postal_code: "10001",
      country: "US"
    }
  },
  
  // Account Summary (denormalized for fast access)
  accounts: [
    {
      account_id: NumberLong(987654321),
      account_number: "ACC1234567890",
      account_type: "CHECKING",
      balance: NumberDecimal("5000.00"),
      available_balance: NumberDecimal("5000.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2020-01-15T00:00:00Z"),
      last_transaction: ISODate("2026-01-31T10:30:00Z")
    },
    {
      account_id: NumberLong(987654322),
      account_number: "ACC1234567891",
      account_type: "SAVINGS",
      balance: NumberDecimal("25000.00"),
      available_balance: NumberDecimal("25000.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2020-02-01T00:00:00Z"),
      last_transaction: ISODate("2026-01-30T15:20:00Z")
    }
  ],
  
  // Transaction Summary (reference to time-series collection)
  transactions: {
    collection: "transactions_ts",
    last_30_days_count: 45,
    last_90_days_count: 120,
    last_year_count: 450,
    total_lifetime_count: 1250,
    last_transaction_date: ISODate("2026-01-31T10:30:00Z")
  },
  
  // Customer Preferences
  preferences: {
    notification_channels: ["email", "sms", "push"],
    language: "en-US",
    timezone: "America/New_York",
    currency_preference: "USD",
    marketing_opt_in: true,
    paperless_statements: true
  },
  
  // Risk and Fraud Detection
  risk_score: 0.75,
  risk_factors: [
    {
      factor: "high_transaction_volume",
      score: 0.3,
      detected_at: ISODate("2026-01-15T00:00:00Z")
    },
    {
      factor: "unusual_location",
      score: 0.2,
      detected_at: ISODate("2026-01-20T00:00:00Z")
    }
  ],
  fraud_indicators: [],
  fraud_ring_connections: [],
  
  // Behavioral Analytics
  behavior: {
    avg_transaction_amount: NumberDecimal("150.00"),
    avg_monthly_transactions: 15,
    preferred_transaction_times: ["09:00", "17:00", "20:00"],
    preferred_merchants: [
      { merchant_id: NumberLong(1001), count: 25 },
      { merchant_id: NumberLong(1002), count: 18 }
    ],
    spending_patterns: {
      groceries: NumberDecimal("500.00"),
      utilities: NumberDecimal("200.00"),
      entertainment: NumberDecimal("300.00")
    }
  },
  
  // Product Holdings
  products: {
    credit_cards: [
      {
        card_id: NumberLong(5555555555555555),
        card_type: "VISA",
        credit_limit: NumberDecimal("10000.00"),
        available_credit: NumberDecimal("7500.00"),
        status: "ACTIVE"
      }
    ],
    loans: [
      {
        loan_id: NumberLong(111111111),
        loan_type: "MORTGAGE",
        principal: NumberDecimal("300000.00"),
        remaining_balance: NumberDecimal("250000.00"),
        monthly_payment: NumberDecimal("1500.00"),
        status: "ACTIVE"
      }
    ],
    investments: []
  },
  
  // Customer Service History
  service_history: {
    total_interactions: 12,
    last_interaction: ISODate("2026-01-25T14:30:00Z"),
    satisfaction_score: 4.5,
    open_tickets: 0,
    resolved_tickets: 12
  },
  
  // Metadata
  metadata: {
    source: "mobile_app",
    acquisition_channel: "referral",
    acquisition_date: ISODate("2020-01-15T00:00:00Z"),
    last_profile_update: ISODate("2026-01-31T10:30:00Z"),
    profile_completeness: 0.95,
    kyc_status: "VERIFIED",
    aml_status: "CLEAR"
  },
  
  // Timestamps
  created_at: ISODate("2020-01-15T00:00:00Z"),
  updated_at: ISODate("2026-01-31T10:30:00Z"),
  version: 1
});

// ============================================================================
// TIME-SERIES COLLECTION FOR TRANSACTIONS
// ============================================================================

// Create time-series collection
db.createCollection("transactions_ts", {
  timeseries: {
    timeField: "timestamp",
    metaField: "customer_id",
    granularity: "seconds",
    bucketMaxSpanSeconds: 3600
  },
  expireAfterSeconds: 63072000  // 2 years retention
});

// Insert sample time-series document
db.transactions_ts.insertOne({
  timestamp: ISODate("2026-01-31T10:30:00Z"),
  customer_id: NumberLong(123456789),
  transaction_id: NumberLong(999888777),
  account_id: NumberLong(987654321),
  transaction_type: "TRANSFER",
  amount: NumberDecimal("1000.00"),
  balance_after: NumberDecimal("4000.00"),
  currency: "USD",
  description: "Transfer to savings account",
  merchant_id: null,
  status: "COMPLETED",
  fraud_score: 0.1,
  location: {
    type: "Point",
    coordinates: [-74.006, 40.7128]  // [longitude, latitude]
  },
  device_info: {
    device_id: "device-123",
    device_type: "mobile",
    os: "iOS",
    app_version: "2.5.1"
  },
  metadata: {
    ip_address: "192.168.1.100",
    user_agent: "Mozilla/5.0...",
    session_id: "session-abc123"
  }
});

// ============================================================================
// INDEXES
// ============================================================================

// Customer collection indexes
db.customers.createIndex({ customer_id: 1 }, { unique: true });
db.customers.createIndex({ "personal_info.email": 1 }, { unique: true });
db.customers.createIndex({ "personal_info.phone.primary": 1 });
db.customers.createIndex({ risk_score: -1 });
db.customers.createIndex({ "accounts.account_id": 1 });
db.customers.createIndex({ "accounts.account_number": 1 });
db.customers.createIndex({ "metadata.kyc_status": 1 });
db.customers.createIndex({ "metadata.aml_status": 1 });
db.customers.createIndex({ created_at: -1 });
db.customers.createIndex({ updated_at: -1 });

// Wildcard index for dynamic profile attributes
db.customers.createIndex({
  "profile.$**": 1,
  "preferences.$**": 1,
  "metadata.$**": 1
});

// Time-series collection indexes
db.transactions_ts.createIndex({ customer_id: 1, timestamp: -1 });
db.transactions_ts.createIndex({ transaction_type: 1, timestamp: -1 });
db.transactions_ts.createIndex({ status: 1, timestamp: -1 });
db.transactions_ts.createIndex({ merchant_id: 1, timestamp: -1 });
db.transactions_ts.createIndex({ "location": "2dsphere" });
db.transactions_ts.createIndex({ fraud_score: -1, timestamp: -1 });

// ============================================================================
// MATERIALIZED VIEWS
// ============================================================================

// Customer analytics monthly materialized view
db.customer_analytics_monthly.insertOne({
  _id: {
    customer_id: NumberLong(123456789),
    year: 2026,
    month: 1
  },
  customer_id: NumberLong(123456789),
  period: {
    year: 2026,
    month: 1,
    start_date: ISODate("2026-01-01T00:00:00Z"),
    end_date: ISODate("2026-01-31T23:59:59Z")
  },
  metrics: {
    total_amount: NumberDecimal("6750.00"),
    transaction_count: 45,
    avg_amount: NumberDecimal("150.00"),
    min_amount: NumberDecimal("10.00"),
    max_amount: NumberDecimal("1000.00"),
    transaction_types: {
      DEPOSIT: 5,
      WITHDRAWAL: 10,
      TRANSFER: 20,
      PAYMENT: 8,
      FEE: 2
    },
    days_active: 30,
    avg_daily_transactions: 1.5
  },
  computed_at: ISODate("2026-02-01T00:00:00Z"),
  version: 1
});

// ============================================================================
// GRAPH COLLECTIONS FOR FRAUD DETECTION
// ============================================================================

// Transaction relationships for fraud ring detection
db.transaction_relationships.insertOne({
  _id: ObjectId(),
  transaction_id: NumberLong(999888777),
  customer_id: NumberLong(123456789),
  related_customer_id: NumberLong(987654321),
  relationship_type: "TRANSFER",
  amount: NumberDecimal("1000.00"),
  timestamp: ISODate("2026-01-31T10:30:00Z"),
  flagged: false,
  fraud_score: 0.1,
  metadata: {
    detected_at: ISODate("2026-01-31T10:30:00Z"),
    detection_method: "automated"
  }
});

// Indexes for graph queries
db.transaction_relationships.createIndex({ customer_id: 1, timestamp: -1 });
db.transaction_relationships.createIndex({ related_customer_id: 1 });
db.transaction_relationships.createIndex({ flagged: 1, timestamp: -1 });
db.transaction_relationships.createIndex({ fraud_score: -1 });

// ============================================================================
// SEARCH INDEX CONFIGURATION (Atlas Search)
// ============================================================================

// Note: This is a configuration example. Actual index creation is done via Atlas UI or API
const searchIndexConfig = {
  name: "customer_search",
  definition: {
    mappings: {
      dynamic: true,
      fields: {
        "personal_info.name.first": {
          type: "autocomplete",
          analyzer: "lucene.standard",
          searchAnalyzer: "lucene.english"
        },
        "personal_info.name.last": {
          type: "autocomplete",
          analyzer: "lucene.standard",
          searchAnalyzer: "lucene.english"
        },
        "personal_info.email": {
          type: "autocomplete",
          analyzer: "lucene.email"
        },
        "personal_info.phone.primary": {
          type: "string",
          analyzer: "lucene.whitespace"
        },
        "accounts.account_type": {
          type: "string",
          analyzer: "lucene.keyword"
        },
        "accounts.account_number": {
          type: "string",
          analyzer: "lucene.keyword"
        },
        "risk_score": {
          type: "number"
        },
        "behavior.avg_transaction_amount": {
          type: "number"
        },
        "products.credit_cards.card_type": {
          type: "string",
          analyzer: "lucene.keyword"
        },
        "metadata.kyc_status": {
          type: "string",
          analyzer: "lucene.keyword"
        }
      }
    }
  }
};

// ============================================================================
// VALIDATION RULES
// ============================================================================

// Add validation schema to customers collection
db.runCommand({
  collMod: "customers",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["customer_id", "personal_info", "created_at"],
      properties: {
        customer_id: {
          bsonType: "long",
          description: "must be a long and is required"
        },
        personal_info: {
          bsonType: "object",
          required: ["name", "email"],
          properties: {
            name: {
              bsonType: "object",
              required: ["first", "last"],
              properties: {
                first: { bsonType: "string" },
                last: { bsonType: "string" }
              }
            },
            email: {
              bsonType: "string",
              pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
            }
          }
        },
        risk_score: {
          bsonType: "double",
          minimum: 0,
          maximum: 1,
          description: "must be a double between 0 and 1"
        },
        accounts: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["account_id", "account_type", "balance"],
            properties: {
              account_id: { bsonType: "long" },
              account_type: {
                enum: ["CHECKING", "SAVINGS", "CREDIT", "LOAN", "INVESTMENT"]
              },
              balance: { bsonType: "decimal" }
            }
          }
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "error"
});

// ============================================================================
// SAMPLE QUERIES
// ============================================================================

// Find customer by email
db.customers.findOne({ "personal_info.email": "john.doe@example.com" });

// Find customers with high risk score
db.customers.find({ risk_score: { $gte: 0.7 } }).sort({ risk_score: -1 });

// Find transactions for a customer in date range
db.transactions_ts.find({
  customer_id: NumberLong(123456789),
  timestamp: {
    $gte: ISODate("2026-01-01T00:00:00Z"),
    $lt: ISODate("2026-02-01T00:00:00Z")
  }
}).sort({ timestamp: -1 });

// Aggregate customer spending by category
db.transactions_ts.aggregate([
  {
    $match: {
      customer_id: NumberLong(123456789),
      timestamp: { $gte: ISODate("2026-01-01T00:00:00Z") }
    }
  },
  {
    $group: {
      _id: "$transaction_type",
      total_amount: { $sum: "$amount" },
      count: { $sum: 1 },
      avg_amount: { $avg: "$amount" }
    }
  },
  {
    $sort: { total_amount: -1 }
  }
]);

// Find nearby transactions using geospatial query
db.transactions_ts.find({
  location: {
    $near: {
      $geometry: {
        type: "Point",
        coordinates: [-74.006, 40.7128]
      },
      $maxDistance: 5000  // 5km radius
    }
  },
  timestamp: { $gte: ISODate("2026-01-31T00:00:00Z") }
});
