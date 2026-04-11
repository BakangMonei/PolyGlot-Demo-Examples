import "dotenv/config";
import crypto from "node:crypto";
import Fastify from "fastify";
import cors from "@fastify/cors";
import rateLimit from "@fastify/rate-limit";
import replyFrom from "@fastify/reply-from";
import jwt from "jsonwebtoken";
import Ajv from "ajv";
import addFormats from "ajv-formats";

const UPSTREAM = process.env.UPSTREAM_ACCOUNT_SERVICE_URL ?? "http://127.0.0.1:7101";
const JWT_SECRET = process.env.JWT_SECRET ?? "dev-only-change-in-production-min-32-chars!!";
const PORT = Number(process.env.PORT ?? 8080);
const RATE_MAX = Number(process.env.RATE_LIMIT_MAX ?? 300);
const RATE_WINDOW = process.env.RATE_LIMIT_WINDOW ?? "1 minute";

const ajv = new Ajv({ allErrors: true, strict: true });
addFormats(ajv);

const createTxSchema = {
  type: "object",
  required: ["account_id", "amount_minor", "type"],
  properties: {
    account_id: { type: "string", minLength: 1, maxLength: 64 },
    amount_minor: { type: "integer" },
    type: { type: "string", enum: ["debit", "credit", "transfer"] },
    counterparty_account_id: { type: ["string", "null"] },
    narrative: { type: "string", maxLength: 512 },
  },
  additionalProperties: false,
} as const;

const validateCreateTx = ajv.compile(createTxSchema);

function correlationId(request: { headers: Record<string, string | string[] | undefined> }): string {
  const h = request.headers["x-correlation-id"];
  const v = Array.isArray(h) ? h[0] : h;
  if (v && v.length > 4) return v;
  return crypto.randomUUID();
}

function assertJwt(authHeader: string | undefined): { sub?: string } {
  if (!authHeader?.startsWith("Bearer ")) {
    const err = new Error("Unauthorized");
    (err as Error & { statusCode?: number }).statusCode = 401;
    throw err;
  }
  const token = authHeader.slice(7);
  try {
    return jwt.verify(token, JWT_SECRET) as { sub?: string };
  } catch {
    const err = new Error("Unauthorized");
    (err as Error & { statusCode?: number }).statusCode = 401;
    throw err;
  }
}

async function buildServer() {
  const app = Fastify({
    logger: { level: process.env.LOG_LEVEL ?? "info" },
    genReqId: (req) => correlationId(req as { headers: Record<string, string | string[] | undefined> }),
  });

  await app.register(cors, { origin: true });
  await app.register(rateLimit, { max: RATE_MAX, timeWindow: RATE_WINDOW });
  await app.register(replyFrom, { global: false });

  app.addHook("onRequest", async (request, reply) => {
    const cid = correlationId(request);
    request.headers["x-correlation-id"] = cid;
    reply.header("x-correlation-id", cid);
  });

  app.get("/v1/health", async () => ({ status: "ok", service: "api-gateway" }));

  app.get("/health", async () => ({ status: "ok", service: "api-gateway" }));

  /** OWASP-style input validation: path params + query */
  const accountIdPattern = /^[a-zA-Z0-9_-]{1,64}$/;

  app.get<{ Params: { id: string } }>("/v1/accounts/:id", async (request, reply) => {
    if (process.env.REQUIRE_JWT !== "false") assertJwt(request.headers.authorization);
    if (!accountIdPattern.test(request.params.id)) {
      return reply.code(400).send({ error: "invalid_account_id" });
    }
    return reply.from(`${UPSTREAM}/accounts/${encodeURIComponent(request.params.id)}`, {
      rewriteHeaders: (headers) => ({
        ...headers,
        "x-correlation-id": String(request.headers["x-correlation-id"] ?? ""),
      }),
    });
  });

  app.post<{ Body: Record<string, unknown> }>("/v1/transactions", async (request, reply) => {
    if (process.env.REQUIRE_JWT !== "false") assertJwt(request.headers.authorization);
    const idem = request.headers["idempotency-key"];
    if (!idem || String(idem).length < 8) {
      return reply.code(400).send({ error: "missing_idempotency_key" });
    }
    if (!validateCreateTx(request.body)) {
      return reply.code(400).send({ error: "validation_failed", details: validateCreateTx.errors });
    }
    return reply.from(`${UPSTREAM}/transactions`, {
      method: "POST",
      body: JSON.stringify(request.body),
      contentType: "application/json",
      rewriteHeaders: (headers) => ({
        ...headers,
        "x-correlation-id": String(request.headers["x-correlation-id"] ?? ""),
        "idempotency-key": String(idem),
      }),
    });
  });

  app.get<{ Params: { accountId: string }; Querystring: { format?: string } }>(
    "/v1/reports/:accountId",
    async (request, reply) => {
      if (process.env.REQUIRE_JWT !== "false") assertJwt(request.headers.authorization);
      if (!accountIdPattern.test(request.params.accountId)) {
        return reply.code(400).send({ error: "invalid_account_id" });
      }
      const fmt = request.query.format ?? "json";
      if (!["json", "pdf", "csv"].includes(fmt)) {
        return reply.code(400).send({ error: "invalid_format" });
      }
      const q = new URLSearchParams({ format: fmt }).toString();
      return reply.from(`${UPSTREAM}/reports/${encodeURIComponent(request.params.accountId)}?${q}`, {
        rewriteHeaders: (headers) => ({
          ...headers,
          "x-correlation-id": String(request.headers["x-correlation-id"] ?? ""),
        }),
      });
    },
  );

  /** Optional: publish to Kafka via env KAFKA_PROXY_URL in full stack */
  app.post("/v1/internal/kafka/ping", async () => ({ ok: true, note: "use messages/ producers in CI" }));

  return app;
}

buildServer()
  .then((app) =>
    app.listen({ port: PORT, host: "0.0.0.0" }).then(() => {
      app.log.info(`API Gateway listening on ${PORT}, upstream=${UPSTREAM}`);
    }),
  )
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
