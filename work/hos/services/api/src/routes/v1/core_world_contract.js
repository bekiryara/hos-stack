import { z } from "zod";
import { canTransitionPazar } from "../../policy/pazar/contract/can_transition.js";
import { isGoogleConfigured } from "./auth/helpers.js";
import { createWorldEnforcer } from "../../worlds/enforce_world.js";

/**
 * Register v1 core, world, contract and proof routes. No behavior change — extracted from app.js.
 */
export async function registerV1CoreWorldContractRoutes(app, { db, legacy = false }) {
  app.get("/health", async () => ({ ok: true }));

  app.get("/ready", async (_req, reply) => {
    try {
      await db.query("select 1");
      return { ok: true };
    } catch {
      return reply.code(503).send({ ok: false });
    }
  });

  // WP-9: World Status + Directory endpoints (GENESIS)
  app.get("/world/status", async () => {
    return {
      world_key: "core",
      availability: "ONLINE",
      phase: "GENESIS",
      version: "1.4.0"
    };
  });

  async function pingWorldAvailability(envKey, defaultBaseUrl, timeoutMs) {
    let url = process.env[envKey] || defaultBaseUrl;
    if (!url.includes("/api/world/status")) {
      url = url.replace(/\/+$/, "") + "/api/world/status";
    }

    const attemptPing = async () => {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await fetch(url, {
          method: "GET",
          signal: controller.signal,
          headers: { "Accept": "application/json" }
        });
        clearTimeout(timeoutId);
        if (response.ok) {
          const data = await response.json();
          if (data.availability === "ONLINE") {
            return "ONLINE";
          }
        }
        return "OFFLINE";
      } catch (e) {
        clearTimeout(timeoutId);
        if (e.name === "AbortError") {
          throw e;
        }
        return "OFFLINE";
      }
    };

    try {
      return await attemptPing();
    } catch (e) {
      if (e.name === "AbortError") {
        try {
          return await attemptPing();
        } catch {
          return "OFFLINE";
        }
      }
      return "OFFLINE";
    }
  }

  app.get("/worlds", async () => {
    const worlds = [
      {
        world_key: "core",
        availability: "ONLINE",
        phase: "GENESIS",
        version: "1.4.0"
      }
    ];

    const timeoutMs = parseInt(process.env.WORLD_PING_TIMEOUT_MS || "2000", 10);
    const [marketplaceAvailability, messagingAvailability] = await Promise.all([
      pingWorldAvailability("PAZAR_STATUS_URL", "http://pazar-app:80", timeoutMs),
      pingWorldAvailability("MESSAGING_STATUS_URL", "http://messaging-api:3000", timeoutMs)
    ]);

    worlds.push({
      world_key: "marketplace",
      availability: marketplaceAvailability,
      phase: "GENESIS",
      version: "1.4.0"
    });

    worlds.push({
      world_key: "messaging",
      availability: messagingAvailability,
      phase: "GENESIS",
      version: "1.4.0"
    });

    worlds.push({
      world_key: "social",
      availability: "DISABLED",
      phase: "GENESIS",
      version: "1.4.0"
    });

    return worlds;
  });

  // REGISTER v1.2 world enforcement (FOUNDING_SPEC)
  const { enforceWorldOrReply } = createWorldEnforcer();

  const contractBody = z.object({
    subject_ref: z.any(),
    to: z.string().min(1),
    meta: z.any().optional(),
    attrs: z.any().optional(),
    idempotency_key: z.string().min(1).optional(),
    ctx: z.any().optional()
  });

  app.post("/contract/can-transition", async (req, reply) => {
    const body = contractBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const world = enforceWorldOrReply(reply, body.data?.ctx?.world);
    if (!world) return;

    const decision = canTransitionPazar({ subject_ref: body.data.subject_ref, to: body.data.to });
    return reply.send({ allowed: !!decision.allowed, reason: decision.reason ?? "unknown" });
  });

  app.post("/contract/transition", async (req, reply) => {
    const body = contractBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const world = enforceWorldOrReply(reply, body.data?.ctx?.world);
    if (!world) return;

    const decision = canTransitionPazar({ subject_ref: body.data.subject_ref, to: body.data.to });
    return reply.send({ ok: true, allowed: !!decision.allowed, reason: decision.reason ?? "unknown" });
  });

  app.get("/meta/features", async (_req, reply) => {
    return reply.send({
      googleOAuthConfigured: isGoogleConfigured(),
      otelEnabled:
        String(process.env.OTEL_ENABLED ?? "").toLowerCase() === "true" ||
        String(process.env.OTEL_ENABLED ?? "") === "1"
    });
  });

  if (!legacy) {
    app.get("/proof", async (req, reply) => {
      const q = req.query ?? {};
      const tenantId = String(q.tenant_id ?? "");
      const worldId = String(q.world_id ?? "");
      const limit = Math.max(1, Math.min(200, Number(q.limit ?? 50)));
      const cursor = String(q.cursor ?? "");

      if (!tenantId || !worldId) return reply.code(400).send({ error: "missing_query" });
      const world = enforceWorldOrReply(reply, worldId);
      if (!world) return;

      const params = [tenantId, world, limit];
      let sql =
        "select proof_id, occurred_at, world, tenant_id, request_id, actor_id, kind, subject_ref, payload, request_hash, idempotency_key, hash from hos_proofs where tenant_id = $1 and world = $2";
      if (cursor) {
        params.splice(2, 0, cursor);
        sql += " and occurred_at < $3";
        sql += " order by occurred_at desc limit $4";
      } else {
        sql += " order by occurred_at desc limit $3";
      }

      const res = await db.query(sql, params);
      const nextCursor = res.rows.length > 0 ? String(res.rows[res.rows.length - 1].occurred_at) : null;
      return reply.send({ items: res.rows, next_cursor: nextCursor });
    });
  }
}
