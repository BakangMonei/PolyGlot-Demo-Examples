# Polyglot Area: Roles and Responsibilities

These roles apply when **authoring or reviewing documentation** (and illustrative snippets) under `polyglot/<language>/`. They help a **builder** team know who signs off on driver choices, security, and SRE alignment—they do not replace your org’s job titles or RACI matrix.

## Which “domain” each language folder emphasizes (example mapping)

| Language folder | Typical bounded context in a large build (example) |
| --------------- | ---------------------------------------------------- |
| **go** | Edge gateways, sidecars, high-concurrency I/O, S3 upload workers |
| **rust** | Hot-path validators, low-latency workers |
| **java** | Core banking services, Spring-centric integration |
| **kotlin** | JVM services, Ktor BFFs, Kafka consumers |
| **scala** | Stream-heavy analytics / reporting |
| **python** | ML fraud scoring, internal tooling, data science handoff |
| **typescript** | BFFs, Node gateways, browser-adjacent APIs |
| **elixir** | Soft-real-time notifications and channels |
| **ruby** | Admin / ops APIs (e.g. Rails) |
| **php** | Legacy adapters (e.g. Laravel) |
| **csharp** | Compliance reporting, .NET integration |
| **dart** | Mobile backends (e.g. Dart Frog) when approved by security |

Reassign domains to match **your** bounded contexts; the table is a planning aid, not a rule. One person may wear several of the roles below; the goal is explicit accountability in reviews and on-call handoffs.

## Role: Polyglot Architect

- Owns **cross-language contracts**: idempotency keys, saga step ordering, outbox vs direct Mongo writes.
- Ensures each `polyglot/<language>/README.md` links to the same repository primitives (`patterns/`, `mysql/schemas/`, `mongodb/schemas/`).
- Resolves conflicts when two language guides recommend incompatible transaction boundaries.

## Role: Language Maintainer (per folder)

- Keeps driver versions, package names, and code samples credible for that ecosystem.
- Adds **CHANGELOG.md** notes in the language folder when samples change behavior (not every typo).
- Runs or documents how to run smoke tests if runnable examples are added later.

## Role: Security Reviewer

- Confirms samples never embed real credentials; secrets come from vault or environment variables.
- Validates TLS, least-privilege DB users, and CSFLE / field-level encryption callouts where applicable.
- Signs off on any new network surface (gRPC, HTTP) documented in language folders.

## Role: SRE / Platform Engineer

- Aligns pooling, timeouts, and circuit breaker guidance with `polyglot/shared/RESILIENCE_AND_POOLING.md` and `observability/SETUP.md`.
- Ensures OpenTelemetry / metrics hooks are mentioned where the runtime has a de-facto standard.

## Role: API / Contract Owner

- Owns repository-wide contracts under **`/shared/`** (OpenAPI, AsyncAPI, proto, JSON Schema) and `polyglot/shared/GRPC_TRANSFER_PROTO.md` where gRPC examples live next to polyglot docs.
- Coordinates breaking-change detection in CI for generated stubs across Java, Rust, C#, Go, etc.

## How to Use This in PRs

Tag reviewers by role in the PR description, for example: “Language Maintainer: @…, Security: @…, SRE: @…”. If a change touches only one runtime, Polyglot Architect review can be lightweight (link check only).
