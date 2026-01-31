# Capacity Planning Model

## 3-Year Projection for Global Banking Platform

## Executive Summary

This capacity planning model projects resource requirements for the hybrid database system over the next 3 years, accounting for growth, seasonal variations, and business expansion.

## Current State (Year 0)

### MySQL 8.0 (System of Record)

| Metric                  | Current    | Unit       |
| ----------------------- | ---------- | ---------- |
| Customers               | 50,000,000 | Count      |
| Transactions per Second | 5,000      | TPS        |
| Data Volume             | 100        | TB         |
| Storage Growth Rate     | 30%        | Per Year   |
| Peak Load Multiplier    | 3x         | Factor     |
| Read/Write Ratio        | 70/30      | Percentage |

### MongoDB 6.0+ (System of Engagement)

| Metric                      | Current     | Unit     |
| --------------------------- | ----------- | -------- |
| Documents                   | 500,000,000 | Count    |
| Read Operations per Second  | 100,000     | OPS      |
| Write Operations per Second | 50,000      | OPS      |
| Data Volume                 | 500         | TB       |
| Storage Growth Rate         | 40%         | Per Year |
| Peak Load Multiplier        | 2.5x        | Factor   |

## Growth Projections

### Year 1 Projections

**Assumptions:**

- Customer growth: 15% annually
- Transaction volume growth: 20% annually
- Data volume growth: 30% (MySQL), 40% (MongoDB)
- New features: +10% load

**MySQL Requirements:**

- Customers: 57,500,000 (+15%)
- Peak TPS: 19,800 (5,000 × 1.2 × 1.1 × 3x peak)
- Data Volume: 130 TB (100 × 1.3)
- Storage Needed: 169 TB (130 × 1.3 for redundancy)

**MongoDB Requirements:**

- Documents: 575,000,000 (+15%)
- Peak Read OPS: 275,000 (100,000 × 1.2 × 1.1 × 2.5x peak)
- Peak Write OPS: 137,500 (50,000 × 1.2 × 1.1 × 2.5x peak)
- Data Volume: 700 TB (500 × 1.4)
- Storage Needed: 910 TB (700 × 1.3 for redundancy)

### Year 2 Projections

**MySQL Requirements:**

- Customers: 66,125,000 (+15%)
- Peak TPS: 23,760 (5,000 × 1.2² × 1.1² × 3x peak)
- Data Volume: 169 TB (130 × 1.3)
- Storage Needed: 220 TB (169 × 1.3)

**MongoDB Requirements:**

- Documents: 661,250,000 (+15%)
- Peak Read OPS: 330,000 (100,000 × 1.2² × 1.1² × 2.5x peak)
- Peak Write OPS: 165,000 (50,000 × 1.2² × 1.1² × 2.5x peak)
- Data Volume: 980 TB (700 × 1.4)
- Storage Needed: 1,274 TB (980 × 1.3)

### Year 3 Projections

**MySQL Requirements:**

- Customers: 76,043,750 (+15%)
- Peak TPS: 28,512 (5,000 × 1.2³ × 1.1³ × 3x peak)
- Data Volume: 220 TB (169 × 1.3)
- Storage Needed: 286 TB (220 × 1.3)

**MongoDB Requirements:**

- Documents: 760,437,500 (+15%)
- Peak Read OPS: 396,000 (100,000 × 1.2³ × 1.1³ × 2.5x peak)
- Peak Write OPS: 198,000 (50,000 × 1.2³ × 1.1³ × 2.5x peak)
- Data Volume: 1,372 TB (980 × 1.4)
- Storage Needed: 1,784 TB (1,372 × 1.3)

## Infrastructure Sizing

### MySQL Infrastructure

#### Year 1

- **Primary Nodes**: 3 (one per region)

  - CPU: 64 cores
  - RAM: 512 GB
  - Storage: 60 TB SSD
  - Network: 25 Gbps

- **Replica Nodes**: 6 (2 per region)

  - CPU: 32 cores
  - RAM: 256 GB
  - Storage: 60 TB SSD
  - Network: 25 Gbps

- **HeatWave Nodes**: 4
  - CPU: 64 cores
  - RAM: 1 TB
  - Storage: 50 TB NVMe
  - Network: 25 Gbps

#### Year 2

- Scale up primary nodes: 96 cores, 768 GB RAM
- Add 2 replica nodes per region (total 9)
- Scale HeatWave to 8 nodes

#### Year 3

- Scale up primary nodes: 128 cores, 1 TB RAM
- Add 3 replica nodes per region (total 12)
- Scale HeatWave to 12 nodes

### MongoDB Infrastructure

#### Year 1

- **Shard Nodes**: 9 (3 shards × 3 nodes)

  - CPU: 32 cores
  - RAM: 256 GB
  - Storage: 120 TB SSD
  - Network: 25 Gbps

- **Config Servers**: 3

  - CPU: 16 cores
  - RAM: 128 GB
  - Storage: 1 TB SSD
  - Network: 10 Gbps

- **Mongos Routers**: 6
  - CPU: 16 cores
  - RAM: 64 GB
  - Storage: 500 GB SSD
  - Network: 25 Gbps

#### Year 2

- Add 3 shards (total 12 shards, 36 nodes)
- Scale shard nodes: 48 cores, 384 GB RAM
- Add 3 mongos routers (total 9)

#### Year 3

- Add 4 shards (total 16 shards, 48 nodes)
- Scale shard nodes: 64 cores, 512 GB RAM
- Add 3 mongos routers (total 12)

## Cost Projection

### Year 1 Costs

**MySQL:**

- Primary nodes (3): $150,000/month
- Replica nodes (6): $90,000/month
- HeatWave (4): $80,000/month
- Storage: $30,000/month
- **Total MySQL: $350,000/month**

**MongoDB:**

- Shard nodes (9): $180,000/month
- Config servers (3): $15,000/month
- Mongos routers (6): $30,000/month
- Storage: $90,000/month
- **Total MongoDB: $315,000/month**

**Total Year 1: $665,000/month = $7,980,000/year**

### Year 2 Costs

**MySQL:**

- Primary nodes (3): $225,000/month
- Replica nodes (9): $135,000/month
- HeatWave (8): $160,000/month
- Storage: $40,000/month
- **Total MySQL: $560,000/month**

**MongoDB:**

- Shard nodes (36): $720,000/month
- Config servers (3): $15,000/month
- Mongos routers (9): $45,000/month
- Storage: $130,000/month
- **Total MongoDB: $910,000/month**

**Total Year 2: $1,470,000/month = $17,640,000/year**

### Year 3 Costs

**MySQL:**

- Primary nodes (3): $300,000/month
- Replica nodes (12): $180,000/month
- HeatWave (12): $240,000/month
- Storage: $50,000/month
- **Total MySQL: $770,000/month**

**MongoDB:**

- Shard nodes (48): $960,000/month
- Config servers (3): $15,000/month
- Mongos routers (12): $60,000/month
- Storage: $180,000/month
- **Total MongoDB: $1,215,000/month**

**Total Year 3: $1,985,000/month = $23,820,000/year**

## Cost Optimization Strategies

### Reserved Instances (30% Savings)

**Year 1 Savings:**

- MySQL: $350,000 × 0.3 = $105,000/month savings
- MongoDB: $315,000 × 0.3 = $94,500/month savings
- **Total Savings: $199,500/month**

**3-Year Total Savings: $7,182,000**

### Spot Instances (70% Savings for Non-Critical)

**Usage:**

- 20% of replica nodes can use spot instances
- Development/test environments

**Year 1 Savings:**

- MySQL replicas: $90,000 × 0.2 × 0.7 = $12,600/month
- MongoDB shards: $180,000 × 0.2 × 0.7 = $25,200/month
- **Total Savings: $37,800/month**

### Data Tiering (50% Savings for Cold Data)

**Strategy:**

- Hot data (last 90 days): SSD
- Warm data (90 days - 2 years): HDD
- Cold data (2+ years): Object storage

**Year 1 Savings:**

- MySQL: $30,000 × 0.3 × 0.5 = $4,500/month
- MongoDB: $90,000 × 0.3 × 0.5 = $13,500/month
- **Total Savings: $18,000/month**

### Compression (30% Storage Reduction)

**Year 1 Savings:**

- MySQL: $30,000 × 0.3 = $9,000/month
- MongoDB: $90,000 × 0.3 = $27,000/month
- **Total Savings: $36,000/month**

### Total Optimized Costs

**Year 1 Optimized:**

- Original: $665,000/month
- Optimized: $373,700/month
- **Savings: $291,300/month (44% reduction)**

**3-Year Total Optimized:**

- Original: $49,440,000
- Optimized: $27,746,400
- **Savings: $21,693,600 (44% reduction)**

## Performance Targets

### Latency Targets

| Metric                    | Year 1 | Year 2 | Year 3 |
| ------------------------- | ------ | ------ | ------ |
| MySQL P99 Write Latency   | <50ms  | <50ms  | <50ms  |
| MySQL P99 Read Latency    | <20ms  | <20ms  | <20ms  |
| MongoDB P99 Read Latency  | <10ms  | <10ms  | <10ms  |
| MongoDB P99 Write Latency | <30ms  | <30ms  | <30ms  |

### Throughput Targets

| Metric                 | Year 1  | Year 2  | Year 3  |
| ---------------------- | ------- | ------- | ------- |
| MySQL Peak TPS         | 19,800  | 23,760  | 28,512  |
| MongoDB Peak Read OPS  | 275,000 | 330,000 | 396,000 |
| MongoDB Peak Write OPS | 137,500 | 165,000 | 198,000 |

## Risk Factors

### High Growth Scenario (+25% customers/year)

- **Impact**: +40% infrastructure costs
- **Mitigation**: Auto-scaling, cloud elasticity

### New Product Launch (+50% load)

- **Impact**: Temporary 50% capacity increase needed
- **Mitigation**: Pre-provisioned capacity, auto-scaling

### Regulatory Changes (Data retention)

- **Impact**: +20% storage requirements
- **Mitigation**: Data tiering, archival strategies

## Recommendations

1. **Year 1**: Implement reserved instances for 30% savings
2. **Year 1**: Set up data tiering for cost optimization
3. **Year 2**: Evaluate auto-scaling solutions
4. **Year 2**: Implement compression for storage savings
5. **Year 3**: Consider multi-cloud for redundancy
6. **Ongoing**: Regular capacity reviews (quarterly)
7. **Ongoing**: Monitor and optimize costs continuously

## Monitoring and Review

### Quarterly Reviews

- Review actual vs projected growth
- Adjust projections based on trends
- Optimize infrastructure based on usage
- Update cost models

### Key Metrics to Track

- Customer growth rate
- Transaction volume growth
- Storage utilization
- Cost per transaction
- Cost per customer
- Infrastructure utilization
