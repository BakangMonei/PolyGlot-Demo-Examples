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
      last: "Doe",
    },
    email: "john.doe@example.com",
    phone: {
      primary: "+1-555-0123",
      mobile: "+1-555-0124",
    }, // Encrypted fields (handled by CSFLE)
    ssn: BinData(6, "..."), // Encrypted via CSFLE
    date_of_birth: BinData(6, "..."), // Encrypted via CSFLE
    drivers_license: BinData(6, "..."), // Encrypted via CSFLE
    address: {
      line1: "123 Main Street",
      line2: "Apt 4B",
      city: "New York",
      state: "NY",
      postal_code: "10001",
      country: "US",
    },
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
      last_transaction: ISODate("2026-01-31T10:30:00Z"),
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
      last_transaction: ISODate("2026-01-30T15:20:00Z"),
    },
  ],

  // Transaction Summary (reference to time-series collection)
  transactions: {
    collection: "transactions_ts",
    last_30_days_count: 45,
    last_90_days_count: 120,
    last_year_count: 450,
    total_lifetime_count: 1250,
    last_transaction_date: ISODate("2026-01-31T10:30:00Z"),
  },

  // Customer Preferences
  preferences: {
    notification_channels: ["email", "sms", "push"],
    language: "en-US",
    timezone: "America/New_York",
    currency_preference: "USD",
    marketing_opt_in: true,
    paperless_statements: true,
  },

  // Risk and Fraud Detection
  risk_score: 0.75,
  risk_factors: [
    {
      factor: "high_transaction_volume",
      score: 0.3,
      detected_at: ISODate("2026-01-15T00:00:00Z"),
    },
    {
      factor: "unusual_location",
      score: 0.2,
      detected_at: ISODate("2026-01-20T00:00:00Z"),
    },
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
      { merchant_id: NumberLong(1002), count: 18 },
    ],
    spending_patterns: {
      groceries: NumberDecimal("500.00"),
      utilities: NumberDecimal("200.00"),
      entertainment: NumberDecimal("300.00"),
    },
  },

  // Product Holdings
  products: {
    credit_cards: [
      {
        card_id: NumberLong(5555555555555555),
        card_type: "VISA",
        credit_limit: NumberDecimal("10000.00"),
        available_credit: NumberDecimal("7500.00"),
        status: "ACTIVE",
      },
    ],
    loans: [
      {
        loan_id: NumberLong(111111111),
        loan_type: "MORTGAGE",
        principal: NumberDecimal("300000.00"),
        remaining_balance: NumberDecimal("250000.00"),
        monthly_payment: NumberDecimal("1500.00"),
        status: "ACTIVE",
      },
    ],
    investments: [],
  },

  // Customer Service History
  service_history: {
    total_interactions: 12,
    last_interaction: ISODate("2026-01-25T14:30:00Z"),
    satisfaction_score: 4.5,
    open_tickets: 0,
    resolved_tickets: 12,
  },

  // Metadata
  metadata: {
    source: "mobile_app",
    acquisition_channel: "referral",
    acquisition_date: ISODate("2020-01-15T00:00:00Z"),
    last_profile_update: ISODate("2026-01-31T10:30:00Z"),
    profile_completeness: 0.95,
    kyc_status: "VERIFIED",
    aml_status: "CLEAR",
  },

  // Timestamps
  created_at: ISODate("2020-01-15T00:00:00Z"),
  updated_at: ISODate("2026-01-31T10:30:00Z"),
  version: 1,
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
  },
  expireAfterSeconds: 63072000,
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
    coordinates: [-74.006, 40.7128], // [longitude, latitude]
  },
  device_info: {
    device_id: "device-123",
    device_type: "mobile",
    os: "iOS",
    app_version: "2.5.1",
  },
  metadata: {
    ip_address: "192.168.1.100",
    user_agent: "Mozilla/5.0...",
    session_id: "session-abc123",
  },
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

db.customers.createIndex({ "profile.$**": 1 });
db.customers.createIndex({ "preferences.$**": 1 });
db.customers.createIndex({ "metadata.$**": 1 });

// Wildcard index for dynamic profile attributes
db.customers.createIndex(
  { "$**": 1 },
  {
    wildcardProjection: {
      profile: 1,
      preferences: 1,
      metadata: 1,
    },
  }
);

// Time-series collection indexes
db.transactions_ts.createIndex({ customer_id: 1, timestamp: -1 });
db.transactions_ts.createIndex({ transaction_type: 1, timestamp: -1 });
db.transactions_ts.createIndex({ status: 1, timestamp: -1 });
db.transactions_ts.createIndex({ merchant_id: 1, timestamp: -1 });
db.transactions_ts.createIndex({ location: "2dsphere" });
db.transactions_ts.createIndex({ fraud_score: -1, timestamp: -1 });

// ============================================================================
// MATERIALIZED VIEWS
// ============================================================================

// Customer analytics monthly materialized view
db.customer_analytics_monthly.insertOne({
  _id: {
    customer_id: NumberLong(123456789),
    year: 2026,
    month: 1,
  },
  customer_id: NumberLong(123456789),
  period: {
    year: 2026,
    month: 1,
    start_date: ISODate("2026-01-01T00:00:00Z"),
    end_date: ISODate("2026-01-31T23:59:59Z"),
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
      FEE: 2,
    },
    days_active: 30,
    avg_daily_transactions: 1.5,
  },
  computed_at: ISODate("2026-02-01T00:00:00Z"),
  version: 1,
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
    detection_method: "automated",
  },
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
          searchAnalyzer: "lucene.english",
        },
        "personal_info.name.last": {
          type: "autocomplete",
          analyzer: "lucene.standard",
          searchAnalyzer: "lucene.english",
        },
        "personal_info.email": {
          type: "autocomplete",
          analyzer: "lucene.email",
        },
        "personal_info.phone.primary": {
          type: "string",
          analyzer: "lucene.whitespace",
        },
        "accounts.account_type": {
          type: "string",
          analyzer: "lucene.keyword",
        },
        "accounts.account_number": {
          type: "string",
          analyzer: "lucene.keyword",
        },
        risk_score: {
          type: "number",
        },
        "behavior.avg_transaction_amount": {
          type: "number",
        },
        "products.credit_cards.card_type": {
          type: "string",
          analyzer: "lucene.keyword",
        },
        "metadata.kyc_status": {
          type: "string",
          analyzer: "lucene.keyword",
        },
      },
    },
  },
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
          description: "must be a long and is required",
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
                last: { bsonType: "string" },
              },
            },
            email: {
              bsonType: "string",
              pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
            },
          },
        },
        risk_score: {
          bsonType: "double",
          minimum: 0,
          maximum: 1,
          description: "must be a double between 0 and 1",
        },
        accounts: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["account_id", "account_type", "balance"],
            properties: {
              account_id: { bsonType: "long" },
              account_type: {
                enum: ["CHECKING", "SAVINGS", "CREDIT", "LOAN", "INVESTMENT"],
              },
              balance: { bsonType: "decimal" },
            },
          },
        },
      },
    },
  },
  validationLevel: "moderate",
  validationAction: "error",
});

// ============================================================================
// SAMPLE QUERIES
// ============================================================================

// Find customer by email
db.customers.findOne({ "personal_info.email": "john.doe@example.com" });

// Find customers with high risk score
db.customers.find({ risk_score: { $gte: 0.7 } }).sort({ risk_score: -1 });

// Find transactions for a customer in date range
db.transactions_ts
  .find({
    customer_id: NumberLong(123456789),
    timestamp: {
      $gte: ISODate("2026-01-01T00:00:00Z"),
      $lt: ISODate("2026-02-01T00:00:00Z"),
    },
  })
  .sort({ timestamp: -1 });

// Aggregate customer spending by category
db.transactions_ts.aggregate([
  {
    $match: {
      customer_id: NumberLong(123456789),
      timestamp: { $gte: ISODate("2026-01-01T00:00:00Z") },
    },
  },
  {
    $group: {
      _id: "$transaction_type",
      total_amount: { $sum: "$amount" },
      count: { $sum: 1 },
      avg_amount: { $avg: "$amount" },
    },
  },
  {
    $sort: { total_amount: -1 },
  },
]);

db.transactions_ts.createIndex({ location: "2dsphere" });
db.transactions_ts.createIndex({ timestamp: 1 }); // optional but recommended
const center = [-74.006, 40.7128];
const radiusKm = 5;
const earthRadiusKm = 6378.1;

// Find nearby transactions using geospatial query
db.transactions_ts.find({
  location: {
    $geoWithin: {
      $centerSphere: [center, radiusKm / earthRadiusKm],
    },
  },
  timestamp: { $gte: ISODate("2026-01-31T00:00:00Z") },
});

db.getCollectionNames();

// ============================================================================
// CUSTOMERS COLLECTION - Customer 360° View
// ============================================================================

// Customer 1: John Doe
db.customers.insertOne({
  customer_id: NumberLong(1),
  personal_info: {
    name: {
      first: "John",
      middle: "Michael",
      last: "Doe",
    },
    email: "john.doeee@example.com",
    phone: {
      primary: "+1-555-0101",
      mobile: "+1-555-0101",
    },
    // Note: In production, these would be encrypted via CSFLE
    ssn: "***-**-6789", // Placeholder - would be BinData(6, "...") with CSFLE
    date_of_birth: "1985-03-15", // Placeholder - would be BinData(6, "...") with CSFLE
    drivers_license: "DL123456789", // Placeholder - would be BinData(6, "...") with CSFLE
    address: {
      line1: "123 Main Street",
      line2: "Apt 4B",
      city: "New York",
      state: "NY",
      postal_code: "10001",
      country: "US",
    },
  },
  accounts: [
    {
      account_id: NumberLong(1),
      account_number: "ACC0000000001",
      account_type: "CHECKING",
      balance: NumberDecimal("3839.50"),
      available_balance: NumberDecimal("3839.50"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2020-01-15T00:00:00Z"),
      last_transaction: ISODate("2024-01-31T00:00:00Z"),
    },
    {
      account_id: NumberLong(2),
      account_number: "ACC0000000002",
      account_type: "SAVINGS",
      balance: NumberDecimal("26025.00"),
      available_balance: NumberDecimal("26025.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2020-02-01T00:00:00Z"),
      last_transaction: ISODate("2024-01-31T00:00:00Z"),
    },
  ],
  transactions: {
    collection: "transactions_ts",
    last_30_days_count: 45,
    last_90_days_count: 120,
    last_year_count: 450,
    total_lifetime_count: 1250,
    last_transaction_date: ISODate("2024-01-31T00:00:00Z"),
  },
  preferences: {
    notification_channels: ["email", "sms", "push"],
    language: "en-US",
    timezone: "America/New_York",
    currency_preference: "USD",
    marketing_opt_in: true,
    paperless_statements: true,
  },
  risk_score: 0.25,
  risk_factors: [],
  fraud_indicators: [],
  fraud_ring_connections: [],
  behavior: {
    avg_transaction_amount: NumberDecimal("150.00"),
    avg_monthly_transactions: 15,
    preferred_transaction_times: ["09:00", "17:00", "20:00"],
    preferred_merchants: [
      { merchant_id: NumberLong(1), count: 25 },
      { merchant_id: NumberLong(2), count: 18 },
    ],
    spending_patterns: {
      groceries: NumberDecimal("500.00"),
      utilities: NumberDecimal("200.00"),
      entertainment: NumberDecimal("300.00"),
    },
  },
  products: {
    credit_cards: [],
    loans: [],
    investments: [],
  },
  service_history: {
    total_interactions: 3,
    last_interaction: ISODate("2024-01-10T14:30:00Z"),
    satisfaction_score: 4.5,
    open_tickets: 0,
    resolved_tickets: 3,
  },
  metadata: {
    source: "mobile_app",
    acquisition_channel: "referral",
    acquisition_date: ISODate("2020-01-15T00:00:00Z"),
    last_profile_update: ISODate("2024-01-31T10:30:00Z"),
    profile_completeness: 0.95,
    kyc_status: "VERIFIED",
    aml_status: "CLEAR",
  },
  created_at: ISODate("2020-01-15T00:00:00Z"),
  updated_at: ISODate("2024-01-31T10:30:00Z"),
  version: 1,
});

// Customer 2: Jane Smith
db.customers.insertOne({
  customer_id: NumberLong(2),
  personal_info: {
    name: {
      first: "Jane",
      middle: null,
      last: "Smith",
    },
    email: "jane.smithhhh@example.com",
    phone: {
      primary: "+1-555-0102",
      mobile: "+1-555-0102",
    },
    ssn: "***-**-7890",
    date_of_birth: "1990-07-22",
    drivers_license: "DL234567890",
    address: {
      line1: "456 Oak Avenue",
      line2: null,
      city: "Los Angeles",
      state: "CA",
      postal_code: "90028",
      country: "US",
    },
  },
  accounts: [
    {
      account_id: NumberLong(3),
      account_number: "ACC0000000003",
      account_type: "CHECKING",
      balance: NumberDecimal("3410.01"),
      available_balance: NumberDecimal("3410.01"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2021-03-10T00:00:00Z"),
      last_transaction: ISODate("2024-01-15T16:45:00Z"),
    },
    {
      account_id: NumberLong(4),
      account_number: "ACC0000000004",
      account_type: "SAVINGS",
      balance: NumberDecimal("15000.00"),
      available_balance: NumberDecimal("15000.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2021-03-10T00:00:00Z"),
      last_transaction: ISODate("2021-03-10T11:05:00Z"),
    },
  ],
  transactions: {
    collection: "transactions_ts",
    last_30_days_count: 28,
    last_90_days_count: 85,
    last_year_count: 320,
    total_lifetime_count: 850,
    last_transaction_date: ISODate("2024-01-15T16:45:00Z"),
  },
  preferences: {
    notification_channels: ["email", "push"],
    language: "en-US",
    timezone: "America/Los_Angeles",
    currency_preference: "USD",
    marketing_opt_in: false,
    paperless_statements: true,
  },
  risk_score: 0.15,
  risk_factors: [],
  fraud_indicators: [],
  fraud_ring_connections: [],
  behavior: {
    avg_transaction_amount: NumberDecimal("85.50"),
    avg_monthly_transactions: 9,
    preferred_transaction_times: ["10:00", "19:00"],
    preferred_merchants: [
      { merchant_id: NumberLong(3), count: 15 },
      { merchant_id: NumberLong(5), count: 12 },
    ],
    spending_patterns: {
      groceries: NumberDecimal("400.00"),
      utilities: NumberDecimal("150.00"),
      entertainment: NumberDecimal("200.00"),
    },
  },
  products: {
    credit_cards: [],
    loans: [],
    investments: [],
  },
  service_history: {
    total_interactions: 1,
    last_interaction: ISODate("2021-03-10T11:10:00Z"),
    satisfaction_score: 5.0,
    open_tickets: 0,
    resolved_tickets: 1,
  },
  metadata: {
    source: "web",
    acquisition_channel: "organic",
    acquisition_date: ISODate("2021-03-10T00:00:00Z"),
    last_profile_update: ISODate("2024-01-15T16:45:00Z"),
    profile_completeness: 0.9,
    kyc_status: "VERIFIED",
    aml_status: "CLEAR",
  },
  created_at: ISODate("2021-03-10T00:00:00Z"),
  updated_at: ISODate("2024-01-15T16:45:00Z"),
  version: 1,
});

// Customer 3: Michael Johnson
db.customers.insertOne({
  customer_id: NumberLong(3),
  personal_info: {
    name: {
      first: "Michael",
      middle: null,
      last: "Johnson",
    },
    email: "michael.j@example.com",
    phone: {
      primary: "+1-555-0103",
      mobile: "+1-555-0103",
    },
    ssn: "***-**-8901",
    date_of_birth: "1988-11-08",
    drivers_license: "DL345678901",
    address: {
      line1: "789 Pine Road",
      line2: "Suite 200",
      city: "Chicago",
      state: "IL",
      postal_code: "60611",
      country: "US",
    },
  },
  accounts: [
    {
      account_id: NumberLong(5),
      account_number: "ACC0000000005",
      account_type: "CHECKING",
      balance: NumberDecimal("7500.00"),
      available_balance: NumberDecimal("7500.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2019-06-20T00:00:00Z"),
      last_transaction: ISODate("2019-06-20T13:20:00Z"),
    },
    {
      account_id: NumberLong(6),
      account_number: "ACC0000000006",
      account_type: "CREDIT",
      balance: NumberDecimal("-500.00"),
      available_balance: NumberDecimal("9500.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2022-01-05T00:00:00Z"),
      last_transaction: ISODate("2024-01-08T10:00:00Z"),
    },
  ],
  transactions: {
    collection: "transactions_ts",
    last_30_days_count: 12,
    last_90_days_count: 35,
    last_year_count: 145,
    total_lifetime_count: 420,
    last_transaction_date: ISODate("2024-01-08T10:00:00Z"),
  },
  preferences: {
    notification_channels: ["email", "sms"],
    language: "en-US",
    timezone: "America/Chicago",
    currency_preference: "USD",
    marketing_opt_in: true,
    paperless_statements: true,
  },
  risk_score: 0.35,
  risk_factors: [
    {
      factor: "high_value_transaction",
      score: 0.2,
      detected_at: ISODate("2024-01-08T10:00:00Z"),
    },
  ],
  fraud_indicators: [],
  fraud_ring_connections: [],
  behavior: {
    avg_transaction_amount: NumberDecimal("250.00"),
    avg_monthly_transactions: 4,
    preferred_transaction_times: ["14:00", "18:00"],
    preferred_merchants: [{ merchant_id: NumberLong(8), count: 8 }],
    spending_patterns: {
      electronics: NumberDecimal("800.00"),
      utilities: NumberDecimal("180.00"),
      entertainment: NumberDecimal("150.00"),
    },
  },
  products: {
    credit_cards: [
      {
        card_id: NumberLong(5555555555555555),
        card_type: "VISA",
        credit_limit: NumberDecimal("10000.00"),
        available_credit: NumberDecimal("9500.00"),
        status: "ACTIVE",
      },
    ],
    loans: [],
    investments: [],
  },
  service_history: {
    total_interactions: 2,
    last_interaction: ISODate("2024-01-08T15:20:00Z"),
    satisfaction_score: 4.0,
    open_tickets: 0,
    resolved_tickets: 2,
  },
  metadata: {
    source: "branch",
    acquisition_channel: "walk_in",
    acquisition_date: ISODate("2019-06-20T00:00:00Z"),
    last_profile_update: ISODate("2024-01-08T15:20:00Z"),
    profile_completeness: 0.85,
    kyc_status: "VERIFIED",
    aml_status: "CLEAR",
  },
  created_at: ISODate("2019-06-20T00:00:00Z"),
  updated_at: ISODate("2024-01-08T15:20:00Z"),
  version: 1,
});

// Customer 4: Sarah Williams
db.customers.insertOne({
  customer_id: NumberLong(4),
  personal_info: {
    name: {
      first: "Sarah",
      middle: null,
      last: "Williams",
    },
    email: "sarah.w@example.com",
    phone: {
      primary: "+1-555-0104",
      mobile: "+1-555-0104",
    },
    ssn: "***-**-9012",
    date_of_birth: "1992-05-30",
    drivers_license: "DL456789012",
    address: {
      line1: "321 Elm Street",
      line2: null,
      city: "Houston",
      state: "TX",
      postal_code: "77001",
      country: "US",
    },
  },
  accounts: [
    {
      account_id: NumberLong(7),
      account_number: "ACC0000000007",
      account_type: "CHECKING",
      balance: NumberDecimal("11985.00"),
      available_balance: NumberDecimal("11985.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2021-08-12T00:00:00Z"),
      last_transaction: ISODate("2024-01-18T18:30:00Z"),
    },
  ],
  transactions: {
    collection: "transactions_ts",
    last_30_days_count: 18,
    last_90_days_count: 52,
    last_year_count: 210,
    total_lifetime_count: 580,
    last_transaction_date: ISODate("2024-01-18T18:30:00Z"),
  },
  preferences: {
    notification_channels: ["email"],
    language: "en-US",
    timezone: "America/Chicago",
    currency_preference: "USD",
    marketing_opt_in: true,
    paperless_statements: true,
  },
  risk_score: 0.2,
  risk_factors: [],
  fraud_indicators: [],
  fraud_ring_connections: [],
  behavior: {
    avg_transaction_amount: NumberDecimal("95.00"),
    avg_monthly_transactions: 6,
    preferred_transaction_times: ["08:00", "17:30"],
    preferred_merchants: [{ merchant_id: NumberLong(6), count: 12 }],
    spending_patterns: {
      transportation: NumberDecimal("300.00"),
      utilities: NumberDecimal("200.00"),
      entertainment: NumberDecimal("250.00"),
    },
  },
  products: {
    credit_cards: [],
    loans: [],
    investments: [],
  },
  service_history: {
    total_interactions: 1,
    last_interaction: ISODate("2024-01-15T09:00:00Z"),
    satisfaction_score: 4.5,
    open_tickets: 0,
    resolved_tickets: 1,
  },
  metadata: {
    source: "mobile_app",
    acquisition_channel: "social_media",
    acquisition_date: ISODate("2021-08-12T00:00:00Z"),
    last_profile_update: ISODate("2024-01-18T18:30:00Z"),
    profile_completeness: 0.88,
    kyc_status: "VERIFIED",
    aml_status: "CLEAR",
  },
  created_at: ISODate("2021-08-12T00:00:00Z"),
  updated_at: ISODate("2024-01-18T18:30:00Z"),
  version: 1,
});

// Customer 5: David Brown
db.customers.insertOne({
  customer_id: NumberLong(5),
  personal_info: {
    name: {
      first: "David",
      middle: null,
      last: "Brown",
    },
    email: "david.brown@example.com",
    phone: {
      primary: "+1-555-0105",
      mobile: "+1-555-0105",
    },
    ssn: "***-**-0123",
    date_of_birth: "1987-09-14",
    drivers_license: "DL567890123",
    address: {
      line1: "654 Maple Drive",
      line2: "Unit 5",
      city: "Phoenix",
      state: "AZ",
      postal_code: "85001",
      country: "US",
    },
  },
  accounts: [
    {
      account_id: NumberLong(8),
      account_number: "ACC0000000008",
      account_type: "CHECKING",
      balance: NumberDecimal("2800.00"),
      available_balance: NumberDecimal("2800.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2023-02-14T00:00:00Z"),
      last_transaction: ISODate("2023-02-14T09:00:00Z"),
    },
    {
      account_id: NumberLong(9),
      account_number: "ACC0000000009",
      account_type: "SAVINGS",
      balance: NumberDecimal("8000.00"),
      available_balance: NumberDecimal("8000.00"),
      currency: "USD",
      status: "ACTIVE",
      opened_date: ISODate("2023-02-14T00:00:00Z"),
      last_transaction: ISODate("2023-02-14T09:05:00Z"),
    },
  ],
  transactions: {
    collection: "transactions_ts",
    last_30_days_count: 5,
    last_90_days_count: 12,
    last_year_count: 45,
    total_lifetime_count: 45,
    last_transaction_date: ISODate("2023-02-14T09:05:00Z"),
  },
  preferences: {
    notification_channels: ["email", "sms", "push"],
    language: "en-US",
    timezone: "America/Phoenix",
    currency_preference: "USD",
    marketing_opt_in: false,
    paperless_statements: true,
  },
  risk_score: 0.1,
  risk_factors: [],
  fraud_indicators: [],
  fraud_ring_connections: [],
  behavior: {
    avg_transaction_amount: NumberDecimal("120.00"),
    avg_monthly_transactions: 2,
    preferred_transaction_times: ["12:00"],
    preferred_merchants: [],
    spending_patterns: {
      groceries: NumberDecimal("200.00"),
      utilities: NumberDecimal("100.00"),
      entertainment: NumberDecimal("50.00"),
    },
  },
  products: {
    credit_cards: [],
    loans: [],
    investments: [],
  },
  service_history: {
    total_interactions: 0,
    last_interaction: null,
    satisfaction_score: null,
    open_tickets: 0,
    resolved_tickets: 0,
  },
  metadata: {
    source: "web",
    acquisition_channel: "online_ad",
    acquisition_date: ISODate("2023-02-14T00:00:00Z"),
    last_profile_update: ISODate("2023-02-14T09:05:00Z"),
    profile_completeness: 0.75,
    kyc_status: "VERIFIED",
    aml_status: "CLEAR",
  },
  created_at: ISODate("2023-02-14T00:00:00Z"),
  updated_at: ISODate("2023-02-14T09:05:00Z"),
  version: 1,
});

// ============================================================================
// TIME-SERIES TRANSACTIONS COLLECTION
// ============================================================================

// Note: Make sure transactions_ts collection is created first using the schema

// Transaction 1: Deposit
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-10T09:15:00Z"),
  customer_id: NumberLong(1),
  transaction_id: NumberLong(3),
  account_id: NumberLong(1),
  transaction_type: "PAYMENT",
  amount: NumberDecimal("-150.00"),
  balance_after: NumberDecimal("4850.00"),
  currency: "USD",
  description: "Payment to Amazon.com",
  merchant_id: NumberLong(1),
  status: "COMPLETED",
  fraud_score: 0.2,
  location: {
    type: "Point",
    coordinates: [-74.006, 40.7128],
  },
  device_info: {
    device_id: "device-123",
    device_type: "mobile",
    os: "iOS",
    app_version: "2.5.1",
  },
  metadata: {
    ip_address: "192.168.1.100",
    user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
    session_id: "session-abc123",
  },
});

// Transaction 2: Starbucks Payment
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-12T08:30:00Z"),
  customer_id: NumberLong(1),
  transaction_id: NumberLong(4),
  account_id: NumberLong(1),
  transaction_type: "PAYMENT",
  amount: NumberDecimal("-5.50"),
  balance_after: NumberDecimal("4844.50"),
  currency: "USD",
  description: "Starbucks Coffee purchase",
  merchant_id: NumberLong(2),
  status: "COMPLETED",
  fraud_score: 0.1,
  location: {
    type: "Point",
    coordinates: [-74.006, 40.7128],
  },
  device_info: {
    device_id: "device-123",
    device_type: "mobile",
    os: "iOS",
    app_version: "2.5.1",
  },
  metadata: {
    ip_address: "192.168.1.100",
    user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
    session_id: "session-abc456",
  },
});

// Transaction 3: Transfer
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-20T10:00:00Z"),
  customer_id: NumberLong(1),
  transaction_id: NumberLong(14),
  account_id: NumberLong(1),
  transaction_type: "TRANSFER",
  amount: NumberDecimal("-1000.00"),
  balance_after: NumberDecimal("3844.50"),
  currency: "USD",
  description: "Transfer to savings account",
  merchant_id: null,
  status: "COMPLETED",
  fraud_score: 0.1,
  location: {
    type: "Point",
    coordinates: [-74.006, 40.7128],
  },
  device_info: {
    device_id: "device-123",
    device_type: "web",
    os: "Windows",
    app_version: "1.0.0",
  },
  metadata: {
    ip_address: "192.168.1.100",
    user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    session_id: "session-xyz789",
  },
});

// Transaction 4: Walmart Purchase
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-15T16:45:00Z"),
  customer_id: NumberLong(2),
  transaction_id: NumberLong(7),
  account_id: NumberLong(3),
  transaction_type: "PAYMENT",
  amount: NumberDecimal("-89.99"),
  balance_after: NumberDecimal("3410.01"),
  currency: "USD",
  description: "Walmart purchase",
  merchant_id: NumberLong(3),
  status: "COMPLETED",
  fraud_score: 0.2,
  location: {
    type: "Point",
    coordinates: [-118.2437, 34.0522],
  },
  device_info: {
    device_id: "device-456",
    device_type: "mobile",
    os: "Android",
    app_version: "2.3.0",
  },
  metadata: {
    ip_address: "192.168.1.200",
    user_agent: "Mozilla/5.0 (Linux; Android 13)",
    session_id: "session-def456",
  },
});

// Transaction 5: Credit Card Purchase
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-08T10:00:00Z"),
  customer_id: NumberLong(3),
  transaction_id: NumberLong(9),
  account_id: NumberLong(6),
  transaction_type: "PAYMENT",
  amount: NumberDecimal("-500.00"),
  balance_after: NumberDecimal("-500.00"),
  currency: "USD",
  description: "Credit card purchase",
  merchant_id: NumberLong(8),
  status: "COMPLETED",
  fraud_score: 0.3,
  location: {
    type: "Point",
    coordinates: [-87.6298, 41.8781],
  },
  device_info: {
    device_id: "device-789",
    device_type: "mobile",
    os: "iOS",
    app_version: "2.1.0",
  },
  metadata: {
    ip_address: "192.168.1.300",
    user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0)",
    session_id: "session-ghi789",
  },
});

// Transaction 6: Uber Ride
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-18T18:30:00Z"),
  customer_id: NumberLong(4),
  transaction_id: NumberLong(11),
  account_id: NumberLong(7),
  transaction_type: "PAYMENT",
  amount: NumberDecimal("-15.00"),
  balance_after: NumberDecimal("11985.00"),
  currency: "USD",
  description: "Uber ride",
  merchant_id: NumberLong(6),
  status: "COMPLETED",
  fraud_score: 0.2,
  location: {
    type: "Point",
    coordinates: [-95.3698, 29.7604],
  },
  device_info: {
    device_id: "device-321",
    device_type: "mobile",
    os: "iOS",
    app_version: "2.4.0",
  },
  metadata: {
    ip_address: "192.168.1.400",
    user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)",
    session_id: "session-jkl012",
  },
});

// Transaction 7: Interest Payment
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-31T00:00:00Z"),
  customer_id: NumberLong(1),
  transaction_id: NumberLong(17),
  account_id: NumberLong(2),
  transaction_type: "INTEREST",
  amount: NumberDecimal("25.00"),
  balance_after: NumberDecimal("26025.00"),
  currency: "USD",
  description: "Monthly interest payment",
  merchant_id: null,
  status: "COMPLETED",
  fraud_score: null,
  location: {
    type: "Point",
    coordinates: [-74.006, 40.7128],
  },
  device_info: {
    device_id: "system",
    device_type: "system",
    os: "Linux",
    app_version: "1.0.0",
  },
  metadata: {
    ip_address: "10.0.0.1",
    user_agent: "BankingSystem/1.0",
    session_id: "system-interest-202401",
  },
});

// Transaction 8: Monthly Fee
db.transactions_ts.insertOne({
  timestamp: ISODate("2024-01-31T00:00:00Z"),
  customer_id: NumberLong(1),
  transaction_id: NumberLong(16),
  account_id: NumberLong(1),
  transaction_type: "FEE",
  amount: NumberDecimal("-5.00"),
  balance_after: NumberDecimal("3839.50"),
  currency: "USD",
  description: "Monthly maintenance fee",
  merchant_id: null,
  status: "COMPLETED",
  fraud_score: null,
  location: {
    type: "Point",
    coordinates: [-74.006, 40.7128],
  },
  device_info: {
    device_id: "system",
    device_type: "system",
    os: "Linux",
    app_version: "1.0.0",
  },
  metadata: {
    ip_address: "10.0.0.1",
    user_agent: "BankingSystem/1.0",
    session_id: "system-fee-202401",
  },
});

// ============================================================================
// TRANSACTION RELATIONSHIPS (Graph Collection)
// ============================================================================

db.transaction_relationships.insertMany([
  {
    transaction_id: NumberLong(14),
    customer_id: NumberLong(1),
    related_customer_id: NumberLong(1), // Same customer (internal transfer)
    relationship_type: "TRANSFER",
    amount: NumberDecimal("1000.00"),
    timestamp: ISODate("2024-01-20T10:00:00Z"),
    flagged: false,
    fraud_score: 0.1,
    metadata: {
      detected_at: ISODate("2024-01-20T10:00:00Z"),
      detection_method: "automated",
    },
  },
  {
    transaction_id: NumberLong(15),
    customer_id: NumberLong(1),
    related_customer_id: NumberLong(1), // Same customer (internal transfer)
    relationship_type: "TRANSFER",
    amount: NumberDecimal("1000.00"),
    timestamp: ISODate("2024-01-20T10:00:00Z"),
    flagged: false,
    fraud_score: 0.1,
    metadata: {
      detected_at: ISODate("2024-01-20T10:00:00Z"),
      detection_method: "automated",
    },
  },
]);

// ============================================================================
// CUSTOMER ANALYTICS MONTHLY (Materialized View)
// ============================================================================

db.customer_analytics_monthly.insertMany([
  {
    _id: {
      customer_id: NumberLong(1),
      year: 2024,
      month: 1,
    },
    customer_id: NumberLong(1),
    period: {
      year: 2024,
      month: 1,
      start_date: ISODate("2024-01-01T00:00:00Z"),
      end_date: ISODate("2024-01-31T23:59:59Z"),
    },
    metrics: {
      total_amount: NumberDecimal("6750.00"),
      transaction_count: 45,
      avg_amount: NumberDecimal("150.00"),
      min_amount: NumberDecimal("5.50"),
      max_amount: NumberDecimal("1000.00"),
      transaction_types: {
        DEPOSIT: 5,
        WITHDRAWAL: 10,
        TRANSFER: 20,
        PAYMENT: 8,
        FEE: 1,
        INTEREST: 1,
      },
      days_active: 30,
      avg_daily_transactions: 1.5,
    },
    computed_at: ISODate("2024-02-01T00:00:00Z"),
    version: 1,
  },
  {
    _id: {
      customer_id: NumberLong(2),
      year: 2024,
      month: 1,
    },
    customer_id: NumberLong(2),
    period: {
      year: 2024,
      month: 1,
      start_date: ISODate("2024-01-01T00:00:00Z"),
      end_date: ISODate("2024-01-31T23:59:59Z"),
    },
    metrics: {
      total_amount: NumberDecimal("2450.00"),
      transaction_count: 28,
      avg_amount: NumberDecimal("87.50"),
      min_amount: NumberDecimal("10.00"),
      max_amount: NumberDecimal("500.00"),
      transaction_types: {
        DEPOSIT: 3,
        PAYMENT: 25,
      },
      days_active: 20,
      avg_daily_transactions: 1.4,
    },
    computed_at: ISODate("2024-02-01T00:00:00Z"),
    version: 1,
  },
]);

// ============================================================================
// VERIFICATION QUERIES
// ============================================================================

print("=== Data Insertion Complete ===");
print("\nCustomer Count: " + db.customers.countDocuments());
print("Transaction Count: " + db.transactions_ts.countDocuments());
print(
  "Transaction Relationships Count: " +
    db.transaction_relationships.countDocuments()
);
print(
  "Analytics Records Count: " + db.customer_analytics_monthly.countDocuments()
);

print("\n=== Sample Customer Query ===");
db.customers.findOne({ customer_id: NumberLong(1) });

print("\n=== Sample Transactions Query ===");
db.transactions_ts
  .find({ customer_id: NumberLong(1) })
  .limit(3)
  .forEach(printjson);

print("\n=== Sample Analytics Query ===");
db.customer_analytics_monthly.findOne({ customer_id: NumberLong(1) });
