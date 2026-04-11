# Shared Contract Layer

Single source of truth for **HTTP** (OpenAPI), **events** (AsyncAPI + JSON Schema), and **gRPC** (Protobuf) used by the API Gateway and polyglot services.

| Asset        | Path                                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------ |
| OpenAPI 3.1  | [openapi/financial-api.yaml](./openapi/financial-api.yaml)                                             |
| AsyncAPI 2.x | [asyncapi/events.yaml](./asyncapi/events.yaml)                                                         |
| Protobuf     | [proto/transactions.proto](./proto/transactions.proto), [proto/accounts.proto](./proto/accounts.proto) |
| JSON Schema  | [schemas/](./schemas/)                                                                                 |

## Usage

- **API Gateway** (`/api`) loads OpenAPI for validation and proxy path mapping.
- **Kafka producers** validate payloads against `schemas/*.json` before publish.
- **gRPC** services code-generate from `proto/` into language-specific modules (see `polyglot/*/account-service` READMEs).

## Governance

- Bump **minor** version for additive changes; **major** for breaking HTTP or topic semantics.
- Run breaking-change checks (`buf breaking`, Spectral) in CI (see `operations/.github/workflows/`).
