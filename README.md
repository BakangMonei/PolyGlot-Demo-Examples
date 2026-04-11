# Hybrid Database Architecture for Global Banking Platform

## Who this repository is for

This project is **documentation for builders**: architects, principal engineers, and platform teams who will **design and implement** a production system—not a single shipped monolith you must deploy as-is. It describes a **financial-grade, hybrid MySQL + MongoDB** architecture, consistency patterns, security and operations posture, and **per-language guidance**. Optional folders (for example `shared/` contract samples, `api/` or `frontend/` sketches, `docker-compose.yml`) exist only as **reference material**; your organization owns the real codebase, pipelines, and cloud accounts.

**Start here:** [BUILDERS_GUIDE.md](./BUILDERS_GUIDE.md)

## Executive summary (documentation scope)

The docs describe a fault-tolerant, compliance-oriented platform serving very large customer and transaction volumes, with **MySQL 8.x as system of record** and **MongoDB 7.x-class** capabilities as system of engagement, coordinated by event-driven and saga-style patterns. Targets (latency, TPS, RTO/RPO) appear in [architecture/TECHNICAL_ARCHITECTURE.md](./architecture/TECHNICAL_ARCHITECTURE.md), [performance/BENCHMARK_REPORT.md](./performance/BENCHMARK_REPORT.md), and [EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md)—use them as **design targets** when you size your own build.

## Architecture overview (conceptual)

### Tier 1: MySQL 8.0 (System of Record)

- Replication and high-availability topologies as documented  
- Sharding / routing patterns (Vitess, ProxySQL, or equivalent)  
- ACID financial ledgers, migrations, and audit expectations  

### Tier 2: MongoDB 7.x-class (System of Engagement)

- Document models, time-series and search patterns where applicable  
- Change streams and engagement-side projections  

## Key themes in the documentation

- **Fault tolerance and DR** — `disaster-recovery/`, RTO/RPO narratives  
- **Regulatory alignment** — `security/`, mapping you must complete for your jurisdiction  
- **Data consistency** — `patterns/` (Saga, CQRS, Data Mesh)  
- **Performance and capacity** — `performance/`, `capacity-planning/`  
- **Observability** — `observability/`  
- **Polyglot clients and service notes** — `polyglot/`  

## Repository structure (documentation map)

```
├── BUILDERS_GUIDE.md     # How to use this repo as an implementer
├── architecture/         # C4-style narrative, data flows, technical architecture
├── shared/               # Sample OpenAPI / AsyncAPI / proto / JSON Schema (contracts to copy)
├── api/                  # Optional gateway sketch (not required to run)
├── frontend/             # Optional SPA sketch
├── messages/             # Kafka topic and producer documentation / samples
├── aws/                  # AWS integration notes and Terraform sketches (if present)
├── mysql/                # MySQL setup, schemas, Flyway-style SQL examples
├── mongodb/              # MongoDB setup and schema examples
├── patterns/             # Saga, CQRS, Data Mesh
├── security/             # Security and compliance documentation
├── observability/        # Monitoring, tracing, alerting guidance
├── disaster-recovery/    # DR runbooks
├── migrations/           # Migration playbooks
├── capacity-planning/    # Capacity models
├── innovation/           # Roadmap-style topics
├── operations/           # Team topology, K8s/Helm samples, CI templates
└── polyglot/             # Per-language implementation notes + roles
```

## Quick start (for readers, not a single deploy button)

1. Read [BUILDERS_GUIDE.md](./BUILDERS_GUIDE.md).  
2. Read [architecture/TECHNICAL_ARCHITECTURE.md](./architecture/TECHNICAL_ARCHITECTURE.md).  
3. Follow [mysql/SETUP.md](./mysql/SETUP.md) and [mongodb/SETUP.md](./mongodb/SETUP.md) when you provision **your** environments.  
4. Apply [patterns/](./patterns/) in **your** services and event pipelines.  
5. Use [observability/SETUP.md](./observability/SETUP.md) as a checklist for what to instrument.  
6. Use [polyglot/README.md](./polyglot/README.md) when you assign languages to bounded contexts.

## Success criteria

The documentation supports teams aiming at outcomes such as: high availability, strict financial consistency on the SoR side, controlled eventual consistency on the SoE side, auditability, and defensible security and DR stories. Exact SLAs and certification are **your** responsibility after implementation.

## License

Proprietary - Global Banking & Financial Services Platform
