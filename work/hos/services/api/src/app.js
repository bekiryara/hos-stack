import Fastify from "fastify";
import crypto from "node:crypto";
import pino from "pino";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import cookie from "@fastify/cookie";
import * as promClient from "prom-client";
import { verifyAccessToken } from "./auth.js";
import { registerOidcPublicRoutes } from "./routes/oidc_public.js";
import { registerV1Routes } from "./routes/v1/index.js";

let metricsInitialized = false;
let httpRequestDurationSeconds;
let httpRequestsTotal;

export async function buildApp({ db, logStream } = {}) {
  if (!db) throw new Error("buildApp requires db");

  const logger = pino(
    {
      level: process.env.LOG_LEVEL || "info",
      // Prevent accidental secret leakage via request logging.
      redact: {
        paths: [
          "req.headers.authorization",
          "req.headers.cookie",
          "req.headers['set-cookie']",
          "req.headers['x-api-key']",
          "req.headers['x-forwarded-authorization']",
          // Common shapes developers might log accidentally:
          "headers.authorization",
          "headers.cookie",
          "headers['set-cookie']",
          "headers['x-api-key']",
          "headers['x-forwarded-authorization']"
        ],
        censor: "[REDACTED]"
      }
    },
    logStream
  );

  const app = Fastify({
    loggerInstance: logger,
    requestIdHeader: "x-request-id",
    genReqId: (req) => {
      const headerId = req.headers["x-request-id"];
      if (typeof headerId === "string" && headerId.length >= 8 && headerId.length <= 200) return headerId;
      return crypto.randomUUID();
    },
    bodyLimit: 1 * 1024 * 1024 // 1 MiB
  });

  await app.register(helmet, {
    // CSP is tricky for APIs and can break dev tooling; keep defaults safe.
    contentSecurityPolicy: false
  });

  await app.register(rateLimit, {
    global: true,
    max: 200,
    timeWindow: "1 minute"
  });

  await app.register(cookie);

  // ===== OIDC (H-OS SSO) — unversioned endpoints (expected by Pazar) =====
  await registerOidcPublicRoutes(app, { db });

  if (!metricsInitialized) {
    promClient.collectDefaultMetrics({ register: promClient.register });

    httpRequestDurationSeconds = new promClient.Histogram({
      name: "hos_http_request_duration_seconds",
      help: "HTTP request duration in seconds",
      labelNames: ["method", "route", "status_code"],
      // Reasonable defaults for an API; adjust once we have SLOs.
      buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
    });

    httpRequestsTotal = new promClient.Counter({
      name: "hos_http_requests_total",
      help: "Total number of HTTP requests",
      labelNames: ["method", "route", "status_code"]
    });

    metricsInitialized = true;
  }

  app.addHook("onRequest", async (req) => {
    // Use BigInt for stable monotonic timing.
    req._hosStartHrtime = process.hrtime.bigint();

    // If a token is present, enrich logs with tenant-scoped context (no PII beyond IDs).
    const auth = req.headers.authorization;
    if (typeof auth === "string" && auth.startsWith("Bearer ")) {
      try {
        const payload = verifyAccessToken(auth.slice("Bearer ".length));
        const tenantId = payload?.tenantId;
        const userId = payload?.sub;
        const role = payload?.role;
        if (tenantId && userId) {
          // pino child logger with stable identifiers for correlation
          req.log = req.log.child({ tenantId, userId, role });
        }
      } catch {
        // ignore invalid token here; auth enforcement happens in route handlers
      }
    }
  });

  app.addHook("onSend", async (req, reply, payload) => {
    // Echo request id so clients can correlate.
    if (req.id) reply.header("x-request-id", String(req.id));
    return payload;
  });

  app.addHook("onResponse", async (req, reply) => {
    const start = req._hosStartHrtime;
    if (typeof start !== "bigint") return;

    const end = process.hrtime.bigint();
    const durationSeconds = Number(end - start) / 1e9;

    const method = req.method;
    const route = req.routeOptions?.url ?? "unknown";
    const statusCode = String(reply.statusCode);

    httpRequestsTotal?.labels(method, route, statusCode).inc(1);
    httpRequestDurationSeconds?.labels(method, route, statusCode).observe(durationSeconds);
  });

  app.get(
    "/metrics",
    { config: { rateLimit: false } },
    async (_req, reply) => {
      reply.header("content-type", promClient.register.contentType);
      return await promClient.register.metrics();
    }
  );

  // Charter: public API should be versioned.
  // Legacy (non-/v1) routes are OFF by default to keep surface area clean (FOUNDING_SPEC alignment).
  const enableLegacy = String(process.env.HOS_ENABLE_LEGACY ?? "").toLowerCase() === "true";
  if (enableLegacy) {
    await app.register(registerV1Routes, { db, legacy: true });
  }
  await app.register(registerV1Routes, { prefix: "/v1", db, legacy: false });

  return app;
}




