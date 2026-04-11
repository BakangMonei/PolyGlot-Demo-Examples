# Builders Guide — Documentation for Implementers

This repository is **documentation-first**: it is meant for **people who will build** a financial-grade, polyglot, hybrid-database platform. It collects **architecture, contracts, schemas, patterns, and operational guidance**. Anything that looks like an application tree (for example `api/`, `frontend/`, `docker-compose.yml`, sample services under `polyglot/*/account-service/`) should be read as **illustrative reference material**, not as a maintained product codebase unless your own program explicitly adopts it. See [docker-compose.README.md](./docker-compose.README.md) for how the compose file is positioned.

## What you should treat as authoritative

| Area | Use it to … |
| ---- | ------------- |
| [architecture/TECHNICAL_ARCHITECTURE.md](./architecture/TECHNICAL_ARCHITECTURE.md) | Understand system context, containers, data planes, and constraints before you choose vendors and regions. |
| [architecture/DATA_FLOW_DIAGRAMS.md](./architecture/DATA_FLOW_DIAGRAMS.md) | Map transaction, fraud, and reporting lifecycles in your own design docs. |
| [shared/openapi/](./shared/openapi/), [shared/asyncapi/](./shared/asyncapi/), [shared/proto/](./shared/proto/), [shared/schemas/](./shared/schemas/) | Copy or fork **contracts** into your own repos; run breaking-change review in your CI. |
| [patterns/](./patterns/) | Implement sagas, CQRS, and mesh boundaries consistently across services. |
| [mysql/](./mysql/), [mongodb/](./mongodb/) | Align physical schemas, indexes, and operational tuning with your SoR / SoE split. |
| [migrations/](./migrations/), [mysql/flyway/](./mysql/flyway/) | Plan **idempotent** migration and rollback strategy; adapt SQL to your naming and tooling. |
| [security/](./security/), [disaster-recovery/](./disaster-recovery/), [operations/](./operations/) | Derive threat models, RTO/RPO, runbooks, and org topology in **your** environment. |
| [polyglot/](./polyglot/) | Pick client libraries, pooling, and saga steps **per language**; reimplement services in your org’s standards. |

## Suggested reading order for a new build team

1. [EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md) — business framing and outcomes you may need to restate for stakeholders.  
2. [architecture/TECHNICAL_ARCHITECTURE.md](./architecture/TECHNICAL_ARCHITECTURE.md) — technical scope and C4-style decomposition.  
3. [shared/README.md](./shared/README.md) — how HTTP, events, and gRPC pieces fit together.  
4. [patterns/SAGA_PATTERN.md](./patterns/SAGA_PATTERN.md) and [patterns/CQRS_PATTERN.md](./patterns/CQRS_PATTERN.md) — consistency model you must implement in code you own.  
5. [mysql/SETUP.md](./mysql/SETUP.md) and [mongodb/SETUP.md](./mongodb/SETUP.md) — operational baseline for the databases you deploy.  
6. [observability/SETUP.md](./observability/SETUP.md) — tracing and metrics expectations for every service **you** ship.  
7. [polyglot/README.md](./polyglot/README.md) and [polyglot/ROLES.md](./polyglot/ROLES.md) — language-specific notes and review roles while you grow the team.

## What you implement yourself

- **Runtime code** for API gateways, BFFs, domain services, workers, and frontends in your own repositories and pipelines.  
- **Infrastructure as code** for your cloud accounts (the `aws/terraform/` tree here is a **starting sketch**, not a drop-in for every account).  
- **Secrets and keys** via your vault (AWS Secrets Manager, HashiCorp Vault, etc.); nothing in this repo should contain real credentials.  
- **CI/CD** (lint, test, security scan, deploy) wired to **your** org’s standards; treat any sample workflow under `operations/` as a template only.

## Using illustrative snippets

- SQL, YAML, Dockerfiles, and small programs in this repo are **examples** to accelerate design reviews.  
- Before production, re-validate **PCI-DSS**, **data residency**, and **key management** against your legal and security sign-off — documentation here is not a compliance attestation.

## Contributing back

If you extend the **documentation** (new pattern, new DR scenario, clearer capacity model), prefer edits to existing markdown in `architecture/`, `patterns/`, `operations/`, and `polyglot/` over adding large runnable trees unless the maintainers explicitly want reference implementations.
