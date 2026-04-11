# Shared Contract Layer

**Documentation and copy-paste contracts** for teams building their own gateway and services: **OpenAPI 3.1**, **AsyncAPI 2.x**, **Protobuf**, and **JSON Schema** samples. Treat files here as the **specification reference** you port into your own repositories; the optional `api/` sketch in this monorepo is only an example of how validation might align with these files—not a required runtime.

| Asset        | Path                                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------ |
| OpenAPI 3.1  | [openapi/financial-api.yaml](./openapi/financial-api.yaml)                                             |
| AsyncAPI 2.x | [asyncapi/events.yaml](./asyncapi/events.yaml)                                                         |
| Protobuf     | [proto/transactions.proto](./proto/transactions.proto), [proto/accounts.proto](./proto/accounts.proto) |
| JSON Schema  | [schemas/](./schemas/)                                                                                 |

## Usage (for builders)

- Your **API gateway** (Fastify, Kong, Envoy + WASM, etc.) should load or import the OpenAPI spec and enforce request/response contracts in **your** pipeline.  
- Your **Kafka producers** should validate payloads against `schemas/*.json` (or generated models) before publish.  
- Your **gRPC** services should code-generate from `proto/` in **your** repos; see language notes under `polyglot/` for ecosystem hints.

## Governance

- Bump **minor** version for additive changes; **major** for breaking HTTP or topic semantics.
- Run breaking-change checks (`buf breaking`, Spectral) in CI (see `operations/.github/workflows/`).
