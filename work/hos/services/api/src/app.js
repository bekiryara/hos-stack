import Fastify from "fastify";
import { z } from "zod";
import crypto from "node:crypto";
import pino from "pino";
import jwt from "jsonwebtoken";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import cookie from "@fastify/cookie";
import * as promClient from "prom-client";
import { hashPassword, signAccessToken, verifyAccessToken, verifyPassword } from "./auth.js";
import { audit } from "./audit.js";
import { readEnvOrFile } from "./config.js";
import { canTransitionPazar } from "./policy/pazar/contract/can_transition.js";

let metricsInitialized = false;
let httpRequestDurationSeconds;
let httpRequestsTotal;

function base64Url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function sha256Base64Url(input) {
  return base64Url(crypto.createHash("sha256").update(String(input)).digest());
}

function publicIssuerFromReq(req) {
  const envIssuer = String(process.env.HOS_PUBLIC_ISSUER ?? "").trim();
  if (envIssuer) return envIssuer.replace(/\/+$/, "");

  const xfProto = String(req.headers["x-forwarded-proto"] ?? "").split(",")[0]?.trim();
  const xfHost = String(req.headers["x-forwarded-host"] ?? "").split(",")[0]?.trim();
  const proto = xfProto || "http";
  const host = xfHost || String(req.headers.host ?? "");
  return `${proto}://${host}`.replace(/\/+$/, "");
}

async function ensureOidcSigningKey(db) {
  const existing = await db.query(
    "select kid, public_jwk, private_pem from hos_oidc_keys where is_active = true order by created_at desc limit 1"
  );
  if (existing.rowCount > 0) {
    const row = existing.rows[0];
    return {
      kid: String(row.kid),
      publicJwk: typeof row.public_jwk === "string" ? JSON.parse(row.public_jwk) : row.public_jwk,
      privatePem: String(row.private_pem)
    };
  }

  const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
  const kid = crypto.randomUUID();
  const publicJwk = publicKey.export({ format: "jwk" });
  publicJwk.use = "sig";
  publicJwk.alg = "RS256";
  publicJwk.kid = kid;

  const privatePem = privateKey.export({ format: "pem", type: "pkcs8" });

  await db.query(
    "insert into hos_oidc_keys (id, kid, alg, public_jwk, private_pem, is_active) values ($1,$2,$3,$4,$5,true)",
    [crypto.randomUUID(), kid, "RS256", JSON.stringify(publicJwk), String(privatePem)]
  );

  return { kid, publicJwk, privatePem: String(privatePem) };
}

async function getOrProvisionOidcClient(db, { clientId, redirectUri }) {
  const found = await db.query(
    "select id, client_id, redirect_uris from hos_oidc_clients where client_id = $1 limit 1",
    [clientId]
  );
  if (found.rowCount === 0) {
    // Dev convenience: auto-provision pazar-client for localhost flows.
    const isLocalRedirect = /^https?:\/\/localhost(\/|:)/i.test(String(redirectUri));
    if (clientId !== "pazar-client" || !isLocalRedirect) return null;
    const id = crypto.randomUUID();
    await db.query(
      "insert into hos_oidc_clients (id, client_id, redirect_uris, allowed_worlds) values ($1,$2,$3,$4)",
      [id, clientId, JSON.stringify([redirectUri]), JSON.stringify([])]
    );
    return { id, clientId, redirectUris: [redirectUri] };
  }

  const row = found.rows[0];
  const redirectUris = typeof row.redirect_uris === "string" ? JSON.parse(row.redirect_uris) : row.redirect_uris;
  return {
    id: String(row.id),
    clientId: String(row.client_id),
    redirectUris: Array.isArray(redirectUris) ? redirectUris : []
  };
}

async function registerApiRoutes(app, { db, legacy = false }) {
  if (legacy) {
    // Keep old routes for backwards compatibility, but mark them as deprecated.
    app.addHook("onSend", async (_req, reply, payload) => {
      reply.header("Deprecation", "true");
      reply.header("Sunset", "TBD");
      return payload;
    });
  }

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
  // GET /v1/world/status - Returns HOS (core) world status
  app.get("/world/status", async () => {
    return {
      world_key: "core",
      availability: "ONLINE",
      phase: "GENESIS",
      version: "1.4.0"
    };
  });

  // Shared helper: Ping world availability (WP-38: no duplication)
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
          throw e; // Retry for timeout
        }
        return "OFFLINE";
      }
    };

    try {
      return await attemptPing();
    } catch (e) {
      // Retry once for timeout/AbortError only
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

  // GET /v1/worlds - Returns directory of all worlds with availability
  app.get("/worlds", async () => {
    const worlds = [
      {
        world_key: "core",
        availability: "ONLINE",
        phase: "GENESIS",
        version: "1.4.0"
      }
    ];

    // Ping marketplace and messaging in parallel (WP-38: latency optimization)
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

  // REGISTER v1.2 world enforcement (FOUNDING_SPEC):
  // - ctx.world is mandatory (no default/fallback)
  // - missing/empty ctx.world => 400
  // - closed world => 410 WORLD_CLOSED
  // Canonical allowlist defaults; can be overridden in ops via env.
  // Updated to new system: marketplace, messaging, social
  // Note: 'commerce' kept for backward compatibility during transition
  const CANONICAL_WORLDS = ["marketplace", "messaging", "social", "commerce"];
  const allowedWorlds = new Set(
    String(process.env.HOS_WORLD_ALLOWLIST ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
  );
  if (allowedWorlds.size === 0) {
    for (const w of CANONICAL_WORLDS) allowedWorlds.add(w);
  }
  const closedWorlds = new Set(
    String(process.env.HOS_WORLD_CLOSED ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
  );

  function enforceWorldOrReply(reply, worldRaw) {
    const world = String(worldRaw ?? "").trim();
    if (!world) {
      reply.code(400).send({ error: "missing_world" });
      return null;
    }
    if (!allowedWorlds.has(world)) {
      reply.code(400).send({ error: "invalid_world" });
      return null;
    }
    if (closedWorlds.has(world)) {
      reply.code(410).send({ error: "world_closed", error_subcode: "WORLD_CLOSED" });
      return null;
    }
    return world;
  }

  // --- Pazar remote contract endpoints (minimal) ---
  // These endpoints exist to support Pazar's HosOutboxEvent delivery.
  // They are intentionally stateless for now (no remote proof store / idempotency DB in this minimal build).
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

  const createTenantBody = z.object({
    slug: z.string().min(3).max(50).regex(/^[a-z0-9-]+$/),
    name: z.string().min(1).max(200)
  });

  app.post(
    "/tenants",
    { config: { rateLimit: { max: 30, timeWindow: "1 minute" } } },
    async (req, reply) => {
      const body = createTenantBody.safeParse(req.body);
      if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

      const id = crypto.randomUUID();
      try {
        await db.query("insert into tenants (id, slug, name) values ($1, $2, $3)", [
          id,
          body.data.slug,
          body.data.name
        ]);
        await audit(db, { action: "tenant.create", tenantId: id, metadata: { slug: body.data.slug } });
      } catch (e) {
        if (String(e?.code) === "23505") return reply.code(409).send({ error: "tenant_conflict" });
        throw e;
      }
      return reply.code(201).send({ id, ...body.data });
    }
  );

  // WP-67: Register body with optional tenantSlug
  const registerBody = z.object({
    tenantSlug: z.string().min(3).max(50).optional(),
    email: z.string().email(),
    password: z.string().min(8).max(200)
  });

  app.post(
    "/auth/register",
    { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } },
    async (req, reply) => {
      // WP-67: Validate body (tenantSlug is optional)
      const parsed = registerBody.safeParse(req.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });
      
      const body = parsed.data;
      const DEFAULT_PUBLIC_TENANT_SLUG = readEnvOrFile("DEFAULT_PUBLIC_TENANT_SLUG") || "public";
      
      // WP-67: Use DEFAULT_PUBLIC_TENANT_SLUG if tenantSlug not provided
      const tenantSlug = body.tenantSlug || DEFAULT_PUBLIC_TENANT_SLUG;

      const userId = crypto.randomUUID();
      const passwordHash = hashPassword(body.password);

      // WP-67: Public customer registration (DEFAULT_PUBLIC_TENANT_SLUG) vs tenant-scoped registration
      if (tenantSlug === DEFAULT_PUBLIC_TENANT_SLUG) {
        // WP-67: PUBLIC CUSTOMER REGISTRATION: Use DEFAULT_PUBLIC_TENANT_SLUG
        // Use DEFAULT_PUBLIC_TENANT_SLUG tenant for storage (users table requires tenant_id)
        let publicTenant = await db.query("select id from tenants where slug = $1 limit 1", [DEFAULT_PUBLIC_TENANT_SLUG]);
        if (publicTenant.rowCount === 0) {
          // Create public tenant if it doesn't exist (idempotent)
          const publicTenantId = crypto.randomUUID();
          try {
            await db.query(
              "insert into tenants (id, slug, name, display_name) values ($1, $2, $3, $4)",
              [publicTenantId, DEFAULT_PUBLIC_TENANT_SLUG, "Public Customers", "Public Customers"]
            );
            publicTenant = { rowCount: 1, rows: [{ id: publicTenantId }] };
          } catch (e) {
            // If concurrent creation happened, refetch
            if (String(e?.code) === "23505") {
              publicTenant = await db.query("select id from tenants where slug = $1 limit 1", [DEFAULT_PUBLIC_TENANT_SLUG]);
            } else {
              throw e;
            }
          }
        }
        const tenantId = publicTenant.rows[0].id;
        const role = "member"; // Public customers are members, not owners

        try {
          // WP-67: Public registration allows multiple users (bypass registration_closed)
          // Check if email already exists (across all tenants for public registration)
          const existing = await db.query("select id from users where email = $1 limit 1", [
            body.email.toLowerCase()
          ]);
          if (existing.rowCount > 0) {
            return reply.code(409).send({ error: "user_conflict", message: "Email already registered" });
          }

          await db.query(
            "insert into users (id, tenant_id, email, password_hash, role) values ($1, $2, $3, $4, $5)",
            [userId, tenantId, body.email.toLowerCase(), passwordHash, role]
          );
          // No audit for public registration (no tenant context)
          // Note: JWT includes tenantId for storage, but user has no membership
          const token = signAccessToken({ sub: userId, tenantId: null, role }); // tenantId null for public users
          return reply.code(201).send({ token });
        } catch (e) {
          if (String(e?.code) === "23505") return reply.code(409).send({ error: "user_conflict" });
          throw e;
        }
      } else {
        // TENANT-SCOPED REGISTRATION: Keep existing behavior (backward compatible)
        const tenant = await db.query("select id from tenants where slug = $1", [tenantSlug]);
        if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });

        const tenantId = tenant.rows[0].id;
        const existing = await db.query("select count(*)::int as c from users where tenant_id = $1", [tenantId]);
        const count = existing.rows?.[0]?.c ?? 0;

        // Hardening: allow self-register ONLY for the first user in a tenant.
        if (count > 0) {
          return reply.code(403).send({ error: "registration_closed" });
        }

        const role = "owner";

        try {
          await db.query(
            "insert into users (id, tenant_id, email, password_hash, role) values ($1, $2, $3, $4, $5)",
            [userId, tenantId, body.email.toLowerCase(), passwordHash, role]
          );
          await audit(db, { action: "user.register", tenantId, actorUserId: userId });
        } catch (e) {
          if (String(e?.code) === "23505") return reply.code(409).send({ error: "user_conflict" });
          throw e;
        }

        const token = signAccessToken({ sub: userId, tenantId, role });
        const refresh = await issueRefreshToken({ tenantId, userId });
        reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
        return reply.code(201).send({ token });
      }
    }
  );

  // WP-67: Login body with optional tenantSlug
  const loginBody = z.object({
    tenantSlug: z.string().min(3).max(50).optional(),
    email: z.string().email(),
    password: z.string().min(1).max(200)
  });

  app.post(
    "/auth/login",
    { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } },
    async (req, reply) => {
      // WP-67: Validate body (tenantSlug is optional)
      const parsed = loginBody.safeParse(req.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });
      
      const body = parsed.data;
      const DEFAULT_PUBLIC_TENANT_SLUG = readEnvOrFile("DEFAULT_PUBLIC_TENANT_SLUG") || "public";
      
      // WP-67: Use DEFAULT_PUBLIC_TENANT_SLUG if tenantSlug not provided
      const tenantSlug = body.tenantSlug || DEFAULT_PUBLIC_TENANT_SLUG;

      // WP-67: Public customer login (DEFAULT_PUBLIC_TENANT_SLUG) vs tenant-scoped login
      if (tenantSlug === DEFAULT_PUBLIC_TENANT_SLUG) {
        // PUBLIC CUSTOMER LOGIN: Search by email across all tenants
        // For public customers, we look in the "public" tenant first, then fallback to any tenant
        const user = await db.query(
          "select id, tenant_id, password_hash, role from users where email = $1 limit 1",
          [body.email.toLowerCase()]
        );
        if (user.rowCount === 0) return reply.code(401).send({ error: "invalid_credentials" });
        if (!verifyPassword(body.password, user.rows[0].password_hash))
          return reply.code(401).send({ error: "invalid_credentials" });

        const userRow = user.rows[0];
        // WP-67: Check if user is in DEFAULT_PUBLIC_TENANT_SLUG (public customer)
        const publicTenant = await db.query("select id from tenants where slug = $1 limit 1", [DEFAULT_PUBLIC_TENANT_SLUG]);
        const isPublicCustomer = publicTenant.rowCount > 0 && userRow.tenant_id === publicTenant.rows[0].id;

        const token = signAccessToken({
          sub: userRow.id,
          tenantId: isPublicCustomer ? null : userRow.tenant_id, // null for public customers
          role: userRow.role ?? "member"
        });
        // Only issue refresh token for tenant-scoped users
        if (!isPublicCustomer) {
          const refresh = await issueRefreshToken({ tenantId: userRow.tenant_id, userId: userRow.id });
          reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
          await audit(db, { action: "user.login", tenantId: userRow.tenant_id, actorUserId: userRow.id });
        }
        return reply.send({ token });
      } else {
        // TENANT-SCOPED LOGIN: Keep existing behavior (backward compatible)
        const tenant = await db.query("select id from tenants where slug = $1", [tenantSlug]);
        if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });

        const user = await db.query(
          "select id, password_hash, role from users where tenant_id = $1 and email = $2",
          [tenant.rows[0].id, body.email.toLowerCase()]
        );
        if (user.rowCount === 0) return reply.code(401).send({ error: "invalid_credentials" });
        if (!verifyPassword(body.password, user.rows[0].password_hash))
          return reply.code(401).send({ error: "invalid_credentials" });

        const token = signAccessToken({
          sub: user.rows[0].id,
          tenantId: tenant.rows[0].id,
          role: user.rows[0].role ?? "member"
        });
        const refresh = await issueRefreshToken({ tenantId: tenant.rows[0].id, userId: user.rows[0].id });
        reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
        await audit(db, { action: "user.login", tenantId: tenant.rows[0].id, actorUserId: user.rows[0].id });
        return reply.send({ token });
      }
    }
  );

  // ===== Admin provisioning (protected by X-HOS-API-KEY) =====
  //
  // Purpose:
  // - Let platform ops (Pazar) upsert users/tenants in H-OS so that demo/local users are still "real"
  //   (have a hos_user_id) without relying on open self-registration (which is intentionally closed).
  //
  // Security:
  // - Requires X-HOS-API-KEY to match HOS_API_KEY.
  function requireApiKey(req, reply) {
    const expected = String(readEnvOrFile("HOS_API_KEY") || "");
    if (!expected) {
      reply.code(501).send({ error: "api_key_not_configured" });
      return false;
    }
    const got = String(req?.headers?.["x-hos-api-key"] ?? "");
    if (got !== expected) {
      reply.code(401).send({ error: "invalid_api_key" });
      return false;
    }
    return true;
  }

  const adminUpsertUserBody = z.object({
    tenantSlug: z.string().min(3).max(50).regex(/^[a-z0-9-]+$/),
    tenantName: z.string().min(1).max(200).optional(),
    email: z.string().email(),
    role: z.enum(["member", "admin", "owner"]).optional(),
    password: z.string().min(8).max(200).optional()
  });

  // DEV/OPS bootstrap only: Admin endpoint to upsert membership (WP-49)
  const adminUpsertMembershipBody = z.object({
    tenantSlug: z.string().min(3).max(50).regex(/^[a-z0-9-]+$/),
    userEmail: z.string().email(),
    role: z.enum(["member", "admin", "owner"]).optional()
  });

  app.post("/admin/memberships/upsert", async (req, reply) => {
    if (!requireApiKey(req, reply)) return;

    const parsed = adminUpsertMembershipBody.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const tenantSlug = parsed.data.tenantSlug;
    const userEmail = String(parsed.data.userEmail || "").toLowerCase();
    const role = parsed.data.role || "member";

    // Get tenant by slug
    const tenant = await db.query("select id, slug from tenants where slug = $1 limit 1", [tenantSlug]);
    if (tenant.rowCount === 0) {
      return reply.code(404).send({ error: "tenant_not_found", tenantSlug });
    }
    const tenantId = tenant.rows[0].id;

    // Get user by email (must exist in any tenant for this to work)
    const user = await db.query("select id, email from users where email = $1 limit 1", [userEmail]);
    if (user.rowCount === 0) {
      return reply.code(404).send({ error: "user_not_found", userEmail });
    }
    const userId = user.rows[0].id;

    // Upsert membership (on conflict do nothing if exists)
    try {
      await db.query(
        "insert into memberships (tenant_id, user_id, role, status) values ($1, $2, $3, $4) on conflict (tenant_id, user_id) do update set role = $3, status = $4",
        [tenantId, userId, role, "active"]
      );
      await audit(db, {
        action: "membership.upsert.admin",
        tenantId,
        actorUserId: userId,
        metadata: { userEmail, role }
      });

      return reply.send({
        tenant_id: tenantId,
        tenant_slug: tenantSlug,
        user_id: userId,
        user_email: userEmail,
        role,
        status: "active"
      });
    } catch (e) {
      return reply.code(500).send({ error: "membership_upsert_failed", message: String(e?.message || e) });
    }
  });

  app.post("/admin/users/upsert", async (req, reply) => {
    if (!requireApiKey(req, reply)) return;

    const parsed = adminUpsertUserBody.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const tenantSlug = parsed.data.tenantSlug;
    const tenantName = parsed.data.tenantName || tenantSlug;
    const email = String(parsed.data.email || "").toLowerCase();
    const role = parsed.data.role || "member";

    // Upsert tenant (by slug).
    let tenant = await db.query("select id, slug, name from tenants where slug = $1 limit 1", [tenantSlug]);
    let tenantCreated = false;
    if (tenant.rowCount === 0) {
      const tenantId = crypto.randomUUID();
      try {
        await db.query("insert into tenants (id, slug, name) values ($1, $2, $3)", [
          tenantId,
          tenantSlug,
          tenantName
        ]);
        tenantCreated = true;
        await audit(db, { action: "tenant.create.admin", tenantId, metadata: { slug: tenantSlug } });
      } catch (e) {
        // If a concurrent upsert created it, just refetch.
        if (String(e?.code) !== "23505") throw e;
      }
      tenant = await db.query("select id, slug, name from tenants where slug = $1 limit 1", [tenantSlug]);
    }

    if (tenant.rowCount === 0) return reply.code(500).send({ error: "tenant_upsert_failed" });
    const tenantId = tenant.rows[0].id;

    // Upsert user (by tenant_id + email).
    const existing = await db.query(
      "select id, email, role, created_at from users where tenant_id = $1 and email = $2 limit 1",
      [tenantId, email]
    );
    if (existing.rowCount > 0) {
      return reply.send({
        id: existing.rows[0].id,
        email,
        role: existing.rows[0].role ?? "member",
        tenantId,
        tenantSlug,
        tenantCreated,
        created: false
      });
    }

    const userId = crypto.randomUUID();
    const password = parsed.data.password || base64Url(crypto.randomBytes(24));
    const passwordHash = hashPassword(password);

    try {
      await db.query(
        "insert into users (id, tenant_id, email, password_hash, role) values ($1, $2, $3, $4, $5)",
        [userId, tenantId, email, passwordHash, role]
      );
      await audit(db, {
        action: "user.upsert.admin",
        tenantId,
        actorUserId: userId,
        metadata: { created: true }
      });
    } catch (e) {
      if (String(e?.code) === "23505") {
        // Race: someone created the same (tenant_id,email) concurrently.
        const again = await db.query(
          "select id, email, role, created_at from users where tenant_id = $1 and email = $2 limit 1",
          [tenantId, email]
        );
        if (again.rowCount > 0) {
          return reply.send({
            id: again.rows[0].id,
            email,
            role: again.rows[0].role ?? "member",
            tenantId,
            tenantSlug,
            tenantCreated,
            created: false
          });
        }
      }
      throw e;
    }

    return reply.code(201).send({
      id: userId,
      email,
      role,
      tenantId,
      tenantSlug,
      tenantCreated,
      created: true,
      password
    });
  });

  function oauthCookieOptions() {
    const redirectUri = String(readEnvOrFile("GOOGLE_REDIRECT_URI") || "");
    const cookieSecure =
      process.env.COOKIE_SECURE === "true" ||
      process.env.NODE_ENV === "production" ||
      redirectUri.startsWith("https://");

    return {
      httpOnly: true,
      sameSite: "lax",
      secure: cookieSecure,
      path: "/",
      maxAge: 10 * 60 // 10m
    };
  }

  function sessionCookieOptions(req) {
    // NOTE: Do NOT tie Secure cookies to GOOGLE_REDIRECT_URI. That breaks localhost http dev.
    // Use explicit COOKIE_SECURE, or request proto (via proxy header).
    const cookieSecureEnv = process.env.COOKIE_SECURE;
    const xfProto = String(req?.headers?.["x-forwarded-proto"] ?? "");
    const xfIsHttps = xfProto.split(",")[0]?.trim() === "https";
    const cookieSecure =
      cookieSecureEnv === "true" ? true : cookieSecureEnv === "false" ? false : xfIsHttps;

    return {
      httpOnly: true,
      sameSite: "lax",
      secure: cookieSecure,
      path: "/",
      maxAge: 60 * 60 * 24 * 30 // 30d
    };
  }

  function base64Url(buf) {
    return Buffer.from(buf)
      .toString("base64")
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/g, "");
  }

  function sha256Hex(input) {
    return crypto.createHash("sha256").update(String(input)).digest("hex");
  }

  function canonicalize(value) {
    if (Array.isArray(value)) return value.map(canonicalize);
    if (value && typeof value === "object") {
      const out = {};
      for (const k of Object.keys(value).sort()) {
        out[k] = canonicalize(value[k]);
      }
      return out;
    }
    return value;
  }

  function snapshotHash(snapshot) {
    const json = JSON.stringify(canonicalize(snapshot));
    return sha256Hex(json);
  }

  // ===== FOUNDING_SPEC canonical primitives (minimal) =====
  // Only register these on versioned API (legacy=false).
  if (!legacy) {
    const subjectRefBody = z.object({
      world_id: z.string().min(1),
      tenant_id: z.string().min(1),
      type: z.string().min(1),
      id: z.union([z.string(), z.number()]).optional()
    });

    const permitBody = z.object({
      actor: z.object({ hos_user_id: z.string().min(1) }),
      tenant_id: z.string().min(1),
      subject_ref: subjectRefBody,
      from: z.string().optional(),
      to: z.string().min(1),
      expected_version: z.string().optional(),
      command_key: z.string().min(8).max(200),
      ctx: z.object({ world: z.string().min(1) }).passthrough()
    });

    app.post("/permits", async (req, reply) => {
      const parsed = permitBody.safeParse(req.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

      const body = parsed.data;
      const world = enforceWorldOrReply(reply, body.ctx.world);
      if (!world) return;

      // FOUNDING_SPEC: input.tenant_id MUST == subject_ref.tenant_id (else 422)
      if (String(body.tenant_id) !== String(body.subject_ref.tenant_id)) {
        return reply.code(422).send({ error: "tenant_mismatch" });
      }
      // FOUNDING_SPEC: subject_ref.world_id should match ctx.world
      if (String(body.subject_ref.world_id) !== String(world)) {
        return reply.code(422).send({ error: "world_mismatch" });
      }

      const actorId = String(body.actor.hos_user_id);
      const tenantId = String(body.tenant_id);
      const commandKey = String(body.command_key);

      const snapshot = {
        actor_id: actorId,
        tenant_id: tenantId,
        subject_ref: body.subject_ref,
        from: body.from ?? null,
        to: body.to,
        expected_version: body.expected_version ?? null,
        command_key: commandKey,
        ctx: body.ctx
      };
      const sHash = snapshotHash(snapshot);
      const expiresAt = new Date(Date.now() + 1000 * 60 * 10); // MVP: 10m TTL

      // Issuance idempotency: UNIQUE(actor_id, tenant_id, command_key)
      const permitId = crypto.randomUUID();
      try {
        await db.query(
          `insert into hos_permits
            (permit_id, actor_id, tenant_id, command_key, world, subject_ref, from_status, to_status, expected_version, snapshot, snapshot_hash, expires_at)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
          [
            permitId,
            actorId,
            tenantId,
            commandKey,
            world,
            JSON.stringify(body.subject_ref),
            body.from ?? null,
            body.to,
            body.expected_version ?? null,
            JSON.stringify(snapshot),
            sHash,
            expiresAt.toISOString()
          ]
        );
      } catch (e) {
        if (String(e?.code) !== "23505") throw e;
        const existing = await db.query(
          "select permit_id, snapshot_hash, snapshot, expires_at from hos_permits where actor_id = $1 and tenant_id = $2 and command_key = $3",
          [actorId, tenantId, commandKey]
        );
        if (existing.rowCount === 0) throw e;
        const row = existing.rows[0];
        const rowHash = String(row.snapshot_hash ?? "");
        if (rowHash && rowHash !== sHash) {
          return reply.code(409).send({ error: "idempotency_conflict" });
        }
        return reply.send({
          permit_id: String(row.permit_id),
          permit_sig: null,
          snapshot: typeof row.snapshot === "string" ? JSON.parse(row.snapshot) : row.snapshot,
          snapshot_hash: rowHash,
          expires_at: row.expires_at
        });
      }

      return reply.send({
        permit_id: permitId,
        permit_sig: null,
        snapshot,
        snapshot_hash: sHash,
        expires_at: expiresAt.toISOString()
      });
    });

    const confirmBody = z.object({
      world_id: z.string().min(1),
      world_mutation_id: z.string().min(8),
      new_version: z.string().min(1),
      snapshot_hash: z.string().min(8),
      mutation_hash: z.string().min(8),
      confirmed_at: z.string().min(1)
    });

    app.post("/permits/:permit_id/confirm", async (req, reply) => {
      const permitId = String(req.params?.permit_id ?? "");
      if (!permitId) return reply.code(400).send({ error: "invalid_permit_id" });

      const parsed = confirmBody.safeParse(req.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });
      const body = parsed.data;

      const world = enforceWorldOrReply(reply, body.world_id);
      if (!world) return;

      const permitRes = await db.query(
        "select permit_id, world, snapshot_hash, snapshot, expires_at, actor_id, tenant_id, command_key from hos_permits where permit_id = $1",
        [permitId]
      );
      if (permitRes.rowCount === 0) return reply.code(404).send({ error: "permit_not_found" });
      const permit = permitRes.rows[0];

      if (String(permit.world) !== world) {
        return reply.code(409).send({ error: "world_mismatch" });
      }
      if (String(permit.snapshot_hash) !== String(body.snapshot_hash)) {
        return reply.code(409).send({ error: "BINDING_MISMATCH", error_subcode: "BINDING_MISMATCH", next_action: "MARK_ILLEGAL" });
      }
      const exp = new Date(String(permit.expires_at));
      if (Number.isFinite(exp.getTime()) && exp.getTime() < Date.now()) {
        return reply.code(409).send({ error: "STALE_VERSION", error_subcode: "STALE_VERSION", next_action: "REISSUE_PERMIT" });
      }

      // Idempotent confirm: UNIQUE(permit_id). Duplicate returns same proof_id if world_mutation_id matches.
      const existing = await db.query(
        "select permit_id, world_mutation_id, proof_id from hos_permit_confirms where permit_id = $1",
        [permitId]
      );
      if (existing.rowCount > 0) {
        const row = existing.rows[0];
        if (String(row.world_mutation_id) !== String(body.world_mutation_id)) {
          return reply.code(409).send({ error: "confirm_conflict" });
        }
        return reply.send({ ok: true, proof_id: String(row.proof_id) });
      }

      const proofId = crypto.randomUUID();
      const occurredAt = new Date().toISOString();
      const subjectRef = typeof permit.snapshot === "string" ? JSON.parse(permit.snapshot) : permit.snapshot;

      const proofPayload = {
        permit_id: permitId,
        world_mutation_id: body.world_mutation_id,
        new_version: body.new_version,
        snapshot_hash: body.snapshot_hash,
        mutation_hash: body.mutation_hash,
        confirmed_at: body.confirmed_at
      };

      const requestHash = sha256Hex(JSON.stringify(canonicalize(proofPayload)));
      const proofHash = sha256Hex(JSON.stringify(canonicalize({ subject: subjectRef, payload: proofPayload })));

      await db.query("begin");
      try {
        await db.query(
          `insert into hos_proofs
            (proof_id, occurred_at, world, tenant_id, request_id, actor_id, kind, subject_ref, payload, request_hash, idempotency_key, hash)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
          [
            proofId,
            occurredAt,
            world,
            String(permit.tenant_id),
            req.id ?? null,
            String(permit.actor_id),
            "permit.confirm",
            JSON.stringify(subjectRef),
            JSON.stringify(proofPayload),
            requestHash,
            String(permit.command_key),
            proofHash
          ]
        );

        await db.query(
          `insert into hos_permit_confirms
            (permit_id, world_mutation_id, proof_id, snapshot_hash, mutation_hash, confirmed_at)
           values ($1,$2,$3,$4,$5,$6)`,
          [permitId, body.world_mutation_id, proofId, body.snapshot_hash, body.mutation_hash, body.confirmed_at]
        );
        await db.query("commit");
      } catch (e) {
        await db.query("rollback");
        throw e;
      }

      return reply.send({ ok: true, proof_id: proofId });
    });

    // Minimal proof query for ops/audit (FOUNDING_SPEC).
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

  async function issueRefreshToken({ tenantId, userId, rotatedFrom = null }) {
    const raw = base64Url(crypto.randomBytes(48));
    const id = crypto.randomUUID();
    const tokenHash = sha256Hex(raw);
    const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30); // 30d

    await db.query(
      "insert into refresh_tokens (id, tenant_id, user_id, token_hash, expires_at, rotated_from) values ($1, $2, $3, $4, $5, $6)",
      [id, tenantId, userId, tokenHash, expiresAt.toISOString(), rotatedFrom]
    );

    return { token: raw, id };
  }

  async function revokeRefreshToken(raw) {
    if (!raw) return;
    const tokenHash = sha256Hex(raw);
    await db.query("update refresh_tokens set revoked_at = now() where token_hash = $1 and revoked_at is null", [
      tokenHash
    ]);
  }

  const refreshBody = z.object({
    refreshToken: z.string().min(1).optional()
  });

  app.post("/auth/refresh", { config: { rateLimit: { max: 30, timeWindow: "1 minute" } } }, async (req, reply) => {
    const parsed = refreshBody.safeParse(req.body ?? {});
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const raw = parsed.data.refreshToken || req.cookies?.hos_refresh;
    if (!raw) return reply.code(401).send({ error: "missing_refresh" });

    const tokenHash = sha256Hex(raw);
    const found = await db.query(
      `select rt.id, rt.tenant_id, rt.user_id, u.role
       from refresh_tokens rt
       join users u on u.id = rt.user_id
       where rt.token_hash = $1
         and rt.revoked_at is null
         and rt.expires_at > now()`,
      [tokenHash]
    );

    if (found.rowCount === 0) return reply.code(401).send({ error: "invalid_refresh" });

    const row = found.rows[0];
    // Revoke old token (rotation)
    await db.query("update refresh_tokens set revoked_at = now() where id = $1 and revoked_at is null", [row.id]);

    const next = await issueRefreshToken({ tenantId: row.tenant_id, userId: row.user_id, rotatedFrom: row.id });
    reply.setCookie("hos_refresh", next.token, sessionCookieOptions(req));

    const token = signAccessToken({
      sub: row.user_id,
      tenantId: row.tenant_id,
      role: row.role ?? "member"
    });

    await audit(db, { action: "user.token.refresh", tenantId: row.tenant_id, actorUserId: row.user_id });

    return reply.send({ token });
  });

  app.post("/auth/logout", { config: { rateLimit: { max: 60, timeWindow: "1 minute" } } }, async (req, reply) => {
    const raw = req.cookies?.hos_refresh;
    await revokeRefreshToken(raw);
    reply.clearCookie("hos_refresh", sessionCookieOptions(req));
    return reply.send({ ok: true });
  });

  function sha256Base64Url(input) {
    return base64Url(crypto.createHash("sha256").update(input).digest());
  }

  function isGoogleConfigured() {
    return Boolean(
      readEnvOrFile("GOOGLE_CLIENT_ID") &&
        readEnvOrFile("GOOGLE_CLIENT_SECRET") &&
        readEnvOrFile("GOOGLE_REDIRECT_URI")
    );
  }

  app.get("/meta/features", async (_req, reply) => {
    // Non-sensitive feature flags to help operators verify configuration.
    return reply.send({
      googleOAuthConfigured: isGoogleConfigured(),
      otelEnabled:
        String(process.env.OTEL_ENABLED ?? "").toLowerCase() === "true" ||
        String(process.env.OTEL_ENABLED ?? "") === "1"
    });
  });

  const googleStartQuery = z.object({
    tenantSlug: z.string().min(3).max(50)
  });

  app.get("/auth/google/start", async (req, reply) => {
    if (!isGoogleConfigured()) {
      return reply.code(501).send({ error: "google_oauth_not_configured" });
    }

    const parsed = googleStartQuery.safeParse(req.query ?? {});
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const tenant = await db.query("select id from tenants where slug = $1", [parsed.data.tenantSlug]);
    if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });

    const state = crypto.randomUUID();
    const verifier = base64Url(crypto.randomBytes(32));
    const challenge = sha256Base64Url(verifier);

    const cookieOpts = oauthCookieOptions();

    reply.setCookie("hos_oauth_state", state, cookieOpts);
    reply.setCookie("hos_oauth_verifier", verifier, cookieOpts);
    reply.setCookie("hos_oauth_tenant", parsed.data.tenantSlug, cookieOpts);

    const params = new URLSearchParams({
      client_id: readEnvOrFile("GOOGLE_CLIENT_ID"),
      redirect_uri: readEnvOrFile("GOOGLE_REDIRECT_URI"),
      response_type: "code",
      scope: "openid email profile",
      state,
      code_challenge: challenge,
      code_challenge_method: "S256",
      prompt: "select_account"
    });

    return reply.redirect(`https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`);
  });

  const googleCallbackQuery = z.object({
    code: z.string().min(1),
    state: z.string().min(1)
  });

  app.get("/auth/google/callback", async (req, reply) => {
    if (!isGoogleConfigured()) {
      return reply.code(501).send({ error: "google_oauth_not_configured" });
    }

    const parsed = googleCallbackQuery.safeParse(req.query ?? {});
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const expectedState = req.cookies?.hos_oauth_state;
    const verifier = req.cookies?.hos_oauth_verifier;
    const tenantSlug = req.cookies?.hos_oauth_tenant;

    if (!expectedState || !verifier || !tenantSlug) {
      return reply.code(401).send({ error: "oauth_state_missing" });
    }
    if (parsed.data.state !== expectedState) {
      return reply.code(401).send({ error: "oauth_state_mismatch" });
    }

    // Exchange code for tokens.
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code: parsed.data.code,
        client_id: readEnvOrFile("GOOGLE_CLIENT_ID"),
        client_secret: readEnvOrFile("GOOGLE_CLIENT_SECRET"),
        redirect_uri: readEnvOrFile("GOOGLE_REDIRECT_URI"),
        grant_type: "authorization_code",
        code_verifier: verifier
      })
    });

    if (!tokenRes.ok) {
      const txt = await tokenRes.text().catch(() => "");
      return reply.code(401).send({ error: "oauth_token_exchange_failed", detail: txt.slice(0, 500) });
    }

    const tokenJson = await tokenRes.json();
    const idToken = tokenJson?.id_token;
    if (!idToken) return reply.code(401).send({ error: "missing_id_token" });

    // Validate id_token via Google tokeninfo endpoint (simple + reliable).
    const infoRes = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
    );
    if (!infoRes.ok) {
      const txt = await infoRes.text().catch(() => "");
      return reply.code(401).send({ error: "invalid_google_token", detail: txt.slice(0, 500) });
    }
    const info = await infoRes.json();
    const googleSub = String(info?.sub ?? "");
    const email = String(info?.email ?? "").toLowerCase();
    const emailVerified = String(info?.email_verified ?? "") === "true";
    const aud = String(info?.aud ?? "");

    if (!googleSub || !email) return reply.code(401).send({ error: "invalid_google_claims" });
    if (aud !== readEnvOrFile("GOOGLE_CLIENT_ID")) return reply.code(401).send({ error: "invalid_google_audience" });
    if (!emailVerified) return reply.code(401).send({ error: "email_not_verified" });

    const tenant = await db.query("select id from tenants where slug = $1", [tenantSlug]);
    if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });
    const tenantId = tenant.rows[0].id;

    // Find or create user:
    let user = await db.query(
      "select id, role from users where tenant_id = $1 and google_sub = $2",
      [tenantId, googleSub]
    );

    if (user.rowCount === 0) {
      // Optional: link existing email user if present.
      const byEmail = await db.query("select id, role from users where tenant_id = $1 and email = $2", [
        tenantId,
        email
      ]);
      if (byEmail.rowCount > 0) {
        await db.query("update users set google_sub = $1 where id = $2", [googleSub, byEmail.rows[0].id]);
        user = byEmail;
      } else {
        const userId = crypto.randomUUID();
        const passwordHash = hashPassword(base64Url(crypto.randomBytes(24)));
        const role = "member";
        await db.query(
          "insert into users (id, tenant_id, email, password_hash, role, google_sub) values ($1, $2, $3, $4, $5, $6)",
          [userId, tenantId, email, passwordHash, role, googleSub]
        );
        user = { rowCount: 1, rows: [{ id: userId, role }] };
      }
    }

    const token = signAccessToken({ sub: user.rows[0].id, tenantId, role: user.rows[0].role ?? "member" });
    const refresh = await issueRefreshToken({ tenantId, userId: user.rows[0].id });
    reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
    await audit(db, { action: "user.login.google", tenantId, actorUserId: user.rows[0].id });

    // Clear oauth cookies.
    const cookieOpts = oauthCookieOptions();
    reply.clearCookie("hos_oauth_state", cookieOpts);
    reply.clearCookie("hos_oauth_verifier", cookieOpts);
    reply.clearCookie("hos_oauth_tenant", cookieOpts);

    // If browser navigation, render a minimal page so the user can copy the token.
    const accept = String(req.headers.accept || "");
    if (accept.includes("text/html")) {
      reply.header("content-type", "text/html; charset=utf-8");
      reply.header("cache-control", "no-store");
      return reply.send(`<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>H-OS Login</title></head>
  <body style="font-family:system-ui,Segoe UI,Arial,sans-serif;padding:24px;max-width:900px">
    <h2>Login OK</h2>
    <p>JWT token:</p>
    <textarea style="width:100%;height:140px" readonly>${token}</textarea>
    <p>Test:</p>
    <pre>curl -H "Authorization: Bearer &lt;token&gt;" http://localhost:3000/v1/me</pre>
  </body>
</html>`);
    }

    return reply.send({ token });
  });

  function getBearer(req) {
    const auth = req.headers.authorization;
    if (!auth?.startsWith("Bearer ")) return null;
    return auth.slice("Bearer ".length);
  }

  function requireAuth(req, reply) {
    const token = getBearer(req);
    if (!token) {
      reply.code(401).send({ error: "missing_token" });
      return null;
    }

    try {
      const payload = verifyAccessToken(token);
      // WP-66B: Allow null tenantId for public customers (sub is still required)
      if (!payload?.sub) {
        reply.code(401).send({ error: "invalid_token" });
        return null;
      }
      // tenantId can be null for public customers
      return payload;
    } catch {
      reply.code(401).send({ error: "invalid_token" });
      return null;
    }
  }

  function requireRole(req, reply, allowedRoles) {
    const payload = requireAuth(req, reply);
    if (!payload) return null;
    const role = payload?.role ?? "member";
    if (!allowedRoles.includes(role)) {
      reply.code(403).send({ error: "forbidden", required: allowedRoles, role });
      return null;
    }
    return payload;
  }

  // GET /v1/me - Returns authenticated user info (WP-8)
  app.get("/me", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    
    // Get user details
    const user = await db.query(
      "select id, email, display_name, created_at from users where id = $1 limit 1",
      [userId]
    );

    if (user.rowCount === 0) {
      return reply.code(404).send({ error: "user_not_found" });
    }

    const userRow = user.rows[0];
    
    // Get memberships count
    const membershipsCount = await db.query(
      "select count(*)::int as c from memberships where user_id = $1 and status = 'active'",
      [userId]
    );
    const count = membershipsCount.rows?.[0]?.c ?? 0;

    return reply.send({
      user_id: userRow.id,
      email: userRow.email,
      display_name: userRow.display_name || userRow.email.split("@")[0],
      memberships_count: count
    });
  });

  // WP-66B: GET /v1/me/orders - Returns authenticated user's orders (proxies to Pazar API)
  app.get("/me/orders", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    
    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/orders?buyer_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });
      
      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }
      
      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  // WP-66B: GET /v1/me/rentals - Returns authenticated user's rentals (proxies to Pazar API)
  app.get("/me/rentals", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    
    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/rentals?renter_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });
      
      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }
      
      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  // WP-66B: GET /v1/me/reservations - Returns authenticated user's reservations (proxies to Pazar API)
  app.get("/me/reservations", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const pazarBaseUrl = process.env.PAZAR_API_BASE_URL || "http://pazar-app:80";
    
    try {
      const response = await fetch(`${pazarBaseUrl}/api/v1/reservations?requester_user_id=${userId}`, {
        method: "GET",
        headers: {
          "Authorization": req.headers.authorization || "",
          "Content-Type": "application/json"
        }
      });
      
      if (!response.ok) {
        const errorText = await response.text().catch(() => "");
        return reply.code(response.status).send({ error: "pazar_api_error", message: errorText });
      }
      
      const data = await response.json();
      return reply.send(data);
    } catch (e) {
      return reply.code(502).send({ error: "pazar_api_unavailable", message: String(e.message) });
    }
  });

  // GET /v1/me/memberships - Returns active memberships for authenticated user (WP-8)
  app.get("/me/memberships", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;

    // Query memberships table (canonical model)
    const memberships = await db.query(
      "select m.tenant_id, m.role, m.status, m.created_at, t.slug as tenant_slug, t.display_name as tenant_name from memberships m inner join tenants t on m.tenant_id = t.id where m.user_id = $1 and m.status = 'active' order by m.created_at asc",
      [userId]
    );

    return reply.send({
      items: memberships.rows.map((row) => ({
        tenant_id: row.tenant_id,
        tenant_slug: row.tenant_slug,
        tenant_name: row.tenant_name || row.tenant_slug,
        role: row.role ?? "member",
        status: row.status,
        created_at: row.created_at
      }))
    });
  });

  // POST /tenants/v2 - Create tenant (WP-8) (registered with /v1 prefix -> /v1/tenants/v2)
  // Note: /tenants already exists for admin, so we use /tenants/v2 for user-created tenants
  const createTenantBodyWP8 = z.object({
    slug: z.string().min(3).max(50),
    display_name: z.string().min(1).max(100).optional()
  });

  app.post("/tenants/v2", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const parsed = createTenantBodyWP8.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const userId = payload.sub;
    const slug = parsed.data.slug.toLowerCase().trim();
    const displayName = parsed.data.display_name || slug;

    // Check if tenant with slug already exists
    const existing = await db.query("select id from tenants where slug = $1 limit 1", [slug]);
    if (existing.rowCount > 0) {
      return reply.code(409).send({ error: "tenant_exists", tenant_id: existing.rows[0].id });
    }

    const tenantId = crypto.randomUUID();
    
    try {
      await db.query(
        "insert into tenants (id, slug, name, display_name, status, created_by_user_id) values ($1, $2, $3, $4, $5, $6)",
        [tenantId, slug, displayName, displayName, "active", userId]
      );

      // Auto-create membership (role=owner, status=active)
      await db.query(
        "insert into memberships (tenant_id, user_id, role, status) values ($1, $2, $3, $4) on conflict (tenant_id, user_id) do nothing",
        [tenantId, userId, "owner", "active"]
      );

      await audit(db, { action: "tenant.create", tenantId, actorUserId: userId, metadata: { slug } });

      return reply.code(201).send({
        tenant_id: tenantId,
        slug,
        display_name: displayName,
        status: "active"
      });
    } catch (e) {
      if (String(e?.code) === "23505") {
        return reply.code(409).send({ error: "tenant_exists" });
      }
      throw e;
    }
  });

  // GET /tenants/{tenant_id}/memberships/me - Check membership for authenticated user (WP-8) (registered with /v1 prefix -> /v1/tenants/{id}/memberships/me)
  app.get("/tenants/:tenant_id/memberships/me", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const tenantId = req.params.tenant_id;

    // Validate tenant_id format
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(tenantId)) {
      return reply.code(400).send({ error: "invalid_tenant_id" });
    }

    // Check membership
    const membership = await db.query(
      "select tenant_id, user_id, role, status from memberships where tenant_id = $1 and user_id = $2 and status = 'active' limit 1",
      [tenantId, userId]
    );

    if (membership.rowCount === 0) {
      return reply.send({
        tenant_id: tenantId,
        user_id: userId,
        role: null,
        status: null,
        allowed: false
      });
    }

    const row = membership.rows[0];
    return reply.send({
      tenant_id: row.tenant_id,
      user_id: row.user_id,
      role: row.role,
      status: row.status,
      allowed: true
    });
  });

  const auditQuery = z.object({
    limit: z.coerce.number().int().min(1).max(200).default(50)
  });

  app.get("/audit", async (req, reply) => {
    // Audit logs are sensitive (user activity). Restrict to elevated roles.
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const parsed = auditQuery.safeParse(req.query ?? {});
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const res = await db.query(
      "select id, action, created_at, metadata, actor_user_id from audit_events where tenant_id = $1 order by created_at desc limit $2",
      [payload.tenantId, parsed.data.limit]
    );

    function normalizeMetadata(v) {
      if (v == null) return {};
      if (typeof v === "object") return v;
      if (typeof v === "string") {
        try {
          const parsed = JSON.parse(v);
          return parsed && typeof parsed === "object" ? parsed : {};
        } catch {
          return {};
        }
      }
      return {};
    }

    const items = res.rows.map((r) => ({ ...r, metadata: normalizeMetadata(r.metadata) }));
    return reply.send({ items });
  });

  app.get("/users", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const res = await db.query(
      "select id, email, role, created_at, (google_sub is not null) as google_linked from users where tenant_id = $1 order by created_at asc",
      [payload.tenantId]
    );
    return reply.send({ items: res.rows });
  });

  const patchUserRoleBody = z.object({
    role: z.enum(["member", "admin", "owner"])
  });

  app.patch("/users/:id/role", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const body = patchUserRoleBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const userId = String(req.params?.id || "");
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });

    const current = await db.query("select id, role from users where tenant_id = $1 and id = $2", [
      payload.tenantId,
      userId
    ]);
    if (current.rowCount === 0) return reply.code(404).send({ error: "user_not_found" });

    // Prevent removing the last owner in a tenant.
    const currentRole = current.rows[0].role ?? "member";
    const nextRole = body.data.role;
    if (currentRole === "owner" && nextRole !== "owner") {
      const owners = await db.query(
        "select count(*)::int as c from users where tenant_id = $1 and role = 'owner'",
        [payload.tenantId]
      );
      const count = owners.rows?.[0]?.c ?? 0;
      if (count <= 1) {
        return reply.code(409).send({ error: "cannot_remove_last_owner" });
      }
    }

    await db.query("update users set role = $1 where tenant_id = $2 and id = $3", [
      nextRole,
      payload.tenantId,
      userId
    ]);

    await audit(db, {
      action: "user.role.change",
      tenantId: payload.tenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId, role: nextRole }
    });

    return reply.send({ ok: true });
  });
}

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
  // Pazar expects:
  // - GET  /authorize  (interactive, browser)
  // - POST /token      (JSON)
  // - GET  /userinfo   (Bearer)
  // - GET  /jwks.json  (JSON)
  //
  // Implementation is intentionally minimal (Auth Code + PKCE).
  // Interactive login is done via a tiny HTML page that posts JSON to /oidc/authorize.

  app.get("/jwks.json", async (_req, reply) => {
    const key = await ensureOidcSigningKey(db);
    return reply.send({ keys: [key.publicJwk] });
  });

  app.get("/authorize", async (req, reply) => {
    const q = req.query ?? {};
    const responseType = String(q.response_type ?? "");
    const clientId = String(q.client_id ?? "");
    const redirectUri = String(q.redirect_uri ?? "");
    const scope = String(q.scope ?? "openid");
    const state = String(q.state ?? "");
    const codeChallenge = String(q.code_challenge ?? "");
    const codeChallengeMethod = String(q.code_challenge_method ?? "");
    const world = String(q.world ?? "");

    if (responseType !== "code") return reply.code(400).send({ error: "unsupported_response_type" });
    if (!clientId || !redirectUri) return reply.code(400).send({ error: "invalid_request" });
    if (!state) return reply.code(400).send({ error: "invalid_request", error_description: "missing_state" });
    if (!codeChallenge || codeChallengeMethod !== "S256")
      return reply.code(400).send({ error: "invalid_request", error_description: "pkce_required" });
    if (!world) return reply.code(400).send({ error: "missing_world" });

    const client = await getOrProvisionOidcClient(db, { clientId, redirectUri });
    if (!client) return reply.code(400).send({ error: "invalid_client" });
    if (!client.redirectUris.includes(redirectUri))
      return reply.code(400).send({ error: "invalid_request", error_description: "redirect_uri_not_allowed" });

    const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>H-OS Authorize</title>
  <style>
    body{font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif;margin:24px;max-width:720px}
    .box{border:1px solid #ddd;border-radius:10px;padding:16px}
    label{display:block;margin-top:10px;font-weight:600}
    input{width:100%;padding:10px;border:1px solid #ccc;border-radius:8px;margin-top:6px}
    button{margin-top:14px;padding:10px 14px;border:0;border-radius:8px;background:#111;color:#fff;cursor:pointer}
    .muted{color:#666;font-size:12px;margin-top:8px}
    .err{color:#b00020;margin-top:10px}
  </style>
</head>
<body>
  <h2>H-OS Login (SSO)</h2>
  <div class="box">
    <div id="err" class="err" style="display:none"></div>
    <label>Tenant Slug</label>
    <input id="tenantSlug" placeholder="demo" autocomplete="organization"/>
    <label>Email</label>
    <input id="email" placeholder="you@example.com" autocomplete="email"/>
    <label>Password</label>
    <input id="password" type="password" autocomplete="current-password"/>
    <button id="btn">Sign in</button>
    <div class="muted">Client: ${clientId} · World: ${world}</div>
  </div>
  <script>
    const payload = ${JSON.stringify({
      response_type: responseType,
      client_id: clientId,
      redirect_uri: redirectUri,
      scope,
      state,
      code_challenge: codeChallenge,
      code_challenge_method: codeChallengeMethod,
      world
    })};
    const errEl = document.getElementById('err');
    function showErr(msg){ errEl.textContent = msg; errEl.style.display = 'block'; }
    document.getElementById('btn').addEventListener('click', async () => {
      errEl.style.display = 'none';
      const tenantSlug = document.getElementById('tenantSlug').value.trim();
      const email = document.getElementById('email').value.trim();
      const password = document.getElementById('password').value;
      if(!tenantSlug || !email || !password){ showErr('Missing tenant/email/password'); return; }
      const res = await fetch('/oidc/authorize', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ tenantSlug, email, password, ...payload })
      });
      const json = await res.json().catch(() => ({}));
      if(!res.ok){ showErr(json.error_description || json.error || ('authorize_failed_'+res.status)); return; }
      if(!json.redirect_to){ showErr('missing redirect_to'); return; }
      window.location.assign(json.redirect_to);
    });
  </script>
</body>
</html>`;

    reply.header("content-type", "text/html; charset=utf-8");
    return reply.send(html);
  });

  const oidcAuthorizeBody = z.object({
    tenantSlug: z.string().min(1),
    email: z.string().email(),
    password: z.string().min(1),
    response_type: z.literal("code"),
    client_id: z.string().min(1),
    redirect_uri: z.string().min(1),
    scope: z.string().min(1).optional(),
    state: z.string().min(1),
    code_challenge: z.string().min(20),
    code_challenge_method: z.literal("S256"),
    world: z.string().min(1)
  });

  app.post("/oidc/authorize", async (req, reply) => {
    const parsed = oidcAuthorizeBody.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: "invalid_request", details: parsed.error.flatten() });
    const body = parsed.data;

    const client = await getOrProvisionOidcClient(db, { clientId: body.client_id, redirectUri: body.redirect_uri });
    if (!client) return reply.code(400).send({ error: "invalid_client" });
    if (!client.redirectUris.includes(body.redirect_uri))
      return reply.code(400).send({ error: "invalid_request", error_description: "redirect_uri_not_allowed" });

    const tenant = await db.query("select id from tenants where slug = $1", [body.tenantSlug]);
    if (tenant.rowCount === 0)
      return reply.code(401).send({ error: "access_denied", error_description: "tenant_not_found" });

    const user = await db.query(
      "select id, password_hash, role from users where tenant_id = $1 and email = $2",
      [tenant.rows[0].id, body.email.toLowerCase()]
    );
    if (user.rowCount === 0) return reply.code(401).send({ error: "access_denied", error_description: "invalid_credentials" });
    if (!verifyPassword(body.password, user.rows[0].password_hash))
      return reply.code(401).send({ error: "access_denied", error_description: "invalid_credentials" });

    const code = base64Url(crypto.randomBytes(32));
    const expiresAt = new Date(Date.now() + 1000 * 60 * 5); // 5m

    await db.query(
      `insert into hos_oidc_auth_codes
        (code, client_id, redirect_uri, tenant_id, user_id, scope, world, code_challenge, code_challenge_method, expires_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [
        code,
        body.client_id,
        body.redirect_uri,
        tenant.rows[0].id,
        user.rows[0].id,
        String(body.scope ?? "openid profile email"),
        body.world,
        body.code_challenge,
        body.code_challenge_method,
        expiresAt.toISOString()
      ]
    );

    const sep = body.redirect_uri.includes("?") ? "&" : "?";
    const redirectTo = `${body.redirect_uri}${sep}code=${encodeURIComponent(code)}&state=${encodeURIComponent(body.state)}`;
    return reply.send({ redirect_to: redirectTo });
  });

  const tokenBody = z.object({
    grant_type: z.literal("authorization_code"),
    client_id: z.string().min(1),
    redirect_uri: z.string().min(1),
    code: z.string().min(8),
    code_verifier: z.string().min(20)
  });

  app.post("/token", async (req, reply) => {
    const parsed = tokenBody.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: "invalid_request", details: parsed.error.flatten() });
    const body = parsed.data;

    const client = await getOrProvisionOidcClient(db, { clientId: body.client_id, redirectUri: body.redirect_uri });
    if (!client) return reply.code(400).send({ error: "invalid_client" });
    if (!client.redirectUris.includes(body.redirect_uri))
      return reply.code(400).send({ error: "invalid_request", error_description: "redirect_uri_not_allowed" });

    const codeRes = await db.query(
      "select tenant_id, user_id, scope, world, code_challenge, code_challenge_method, expires_at from hos_oidc_auth_codes where code = $1",
      [body.code]
    );
    if (codeRes.rowCount === 0) return reply.code(400).send({ error: "invalid_grant" });
    const row = codeRes.rows[0];

    const exp = new Date(String(row.expires_at));
    if (Number.isFinite(exp.getTime()) && exp.getTime() < Date.now()) {
      await db.query("delete from hos_oidc_auth_codes where code = $1", [body.code]);
      return reply.code(400).send({ error: "invalid_grant" });
    }

    if (String(row.code_challenge_method) !== "S256") return reply.code(400).send({ error: "invalid_grant" });
    const expectedChallenge = String(row.code_challenge);
    const actualChallenge = sha256Base64Url(body.code_verifier);
    if (expectedChallenge !== actualChallenge) return reply.code(400).send({ error: "invalid_grant" });

    // One-time use
    await db.query("delete from hos_oidc_auth_codes where code = $1", [body.code]);

    const userRes = await db.query("select email, role from users where id = $1", [row.user_id]);
    if (userRes.rowCount === 0) return reply.code(400).send({ error: "invalid_grant" });
    const email = String(userRes.rows[0].email ?? "");
    const role = String(userRes.rows[0].role ?? "member");

    const issuer = publicIssuerFromReq(req);
    const now = Math.floor(Date.now() / 1000);
    const expiresIn = 60 * 15; // 15m

    const key = await ensureOidcSigningKey(db);
    const idTokenPayload = {
      iss: issuer,
      aud: body.client_id,
      sub: String(row.user_id),
      iat: now,
      exp: now + expiresIn,
      email,
      name: email || "user",
      hos_user_id: String(row.user_id),
      tenant_id: String(row.tenant_id),
      world: String(row.world)
    };
    const id_token = jwt.sign(idTokenPayload, key.privatePem, { algorithm: "RS256", keyid: key.kid });

    const access_token = signAccessToken({
      sub: String(row.user_id),
      tenantId: String(row.tenant_id),
      role
    });

    return reply.send({
      token_type: "Bearer",
      expires_in: expiresIn,
      access_token,
      id_token,
      scope: String(row.scope ?? "openid profile email")
    });
  });

  app.get("/userinfo", async (req, reply) => {
    const devVerbose =
      String(process.env.HOS_DEBUG_OIDC ?? "").toLowerCase() === "true" ||
      String(process.env.NODE_ENV ?? "").toLowerCase() !== "production";
    const deny = (desc) =>
      reply
        .code(401)
        .send(devVerbose ? { error: "invalid_token", error_description: String(desc) } : { error: "invalid_token" });

    const authz = String(req.headers.authorization ?? "");
    const m = authz.match(/^Bearer\s+(.+)$/i);
    if (!m) return deny("missing_bearer");
    let payload;
    try {
      payload = verifyAccessToken(m[1]);
    } catch {
      return deny("verify_failed");
    }
    const sub = String(payload?.sub ?? "");
    const tenantId = String(payload?.tenantId ?? payload?.tenant_id ?? "");
    if (!sub || !tenantId) return deny("missing_claims");

    const userRes = await db.query("select email, role from users where id = $1 and tenant_id = $2", [sub, tenantId]);
    if (userRes.rowCount === 0) return deny("user_not_found");
    const email = String(userRes.rows[0].email ?? "");
    const role = String(userRes.rows[0].role ?? "member");

    return reply.send({
      sub,
      hos_user_id: sub,
      email,
      name: email || "user",
      tenant_id: tenantId,
      role
    });
  });

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
    await app.register(registerApiRoutes, { db, legacy: true });
  }
  await app.register(registerApiRoutes, { prefix: "/v1", db, legacy: false });

  return app;
}




