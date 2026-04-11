# API Gateway (illustrative sketch)

This folder contains an **optional Fastify example** showing how an API gateway might validate JWTs, rate-limit, propagate correlation IDs, and proxy to a backend. It is **documentation support material** for implementers—not a required dependency of the rest of the doc set.

When you build for real: host the gateway in your own repo, wire it to your identity provider, import [`../shared/openapi/financial-api.yaml`](../shared/openapi/financial-api.yaml) into your CI, and harden networking and secrets per `security/`.
