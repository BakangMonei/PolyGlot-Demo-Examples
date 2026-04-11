# Polyglot Area: Roles and Responsibilities

Use these roles when extending or reviewing language-specific guides under `polyglot/<language>/`. One person may wear multiple hats; the point is to make **accountabilities explicit** in design reviews and on-call handoffs.

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

- Owns `polyglot/shared/GRPC_TRANSFER_PROTO.md` and protobuf package versioning (`banking.transfer.v1`, `v2`, …).
- Coordinates breaking-change detection in CI for generated stubs across Java, Rust, C#, Go, etc.

## How to Use This in PRs

Tag reviewers by role in the PR description, for example: “Language Maintainer: @…, Security: @…, SRE: @…”. If a change touches only one runtime, Polyglot Architect review can be lightweight (link check only).
