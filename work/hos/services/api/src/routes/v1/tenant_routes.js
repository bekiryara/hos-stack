import crypto from "node:crypto";
import { z } from "zod";
import { audit } from "../../audit.js";
import { requireAuth } from "./request_auth.js";

/**
 * Register v1 tenant routes (POST /tenants, POST /tenants/v2, GET /tenants/:id/memberships/me). No behavior change — split from auth_me_tenants.js.
 */
export async function registerV1TenantRoutes(app, { db }) {
  const createTenantBody = z.object({
    slug: z.string().min(3).max(50).regex(/^[a-z0-9-]+$/),
    name: z.string().min(1).max(200)
  });

  async function insertTenantAndEnsureOwnerMembership({ tenantId, slug, displayName, userId }) {
    // Single implementation for tenant creation + owner membership + audit.
    await db.query(
      "insert into tenants (id, slug, name, display_name, status, created_by_user_id) values ($1, $2, $3, $4, $5, $6)",
      [tenantId, slug, displayName, displayName, "active", userId]
    );

    await db.query(
      "insert into memberships (tenant_id, user_id, role, status) values ($1, $2, $3, $4) on conflict (tenant_id, user_id) do nothing",
      [tenantId, userId, "owner", "active"]
    );

    await audit(db, { action: "tenant.create", tenantId: tenantId, actorUserId: userId, metadata: { slug } });
  }

  app.post(
    "/tenants",
    { config: { rateLimit: { max: 30, timeWindow: "1 minute" } } },
    async (req, reply) => {
      // Lockdown: tenant creation must be authenticated (prevents open surface drift).
      const payload = requireAuth(req, reply);
      if (!payload) return;

      const body = createTenantBody.safeParse(req.body);
      if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

      const id = crypto.randomUUID();
      try {
        await insertTenantAndEnsureOwnerMembership({
          tenantId: id,
          slug: body.data.slug,
          displayName: body.data.name,
          userId: payload.sub
        });
      } catch (e) {
        if (String(e?.code) === "23505") return reply.code(409).send({ error: "tenant_conflict" });
        throw e;
      }
      return reply.code(201).send({ id, ...body.data });
    }
  );

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

    const existing = await db.query("select id from tenants where slug = $1 limit 1", [slug]);
    if (existing.rowCount > 0) {
      return reply.code(409).send({ error: "tenant_exists", tenant_id: existing.rows[0].id });
    }

    const tenantId = crypto.randomUUID();

    try {
      await insertTenantAndEnsureOwnerMembership({
        tenantId,
        slug,
        displayName,
        userId
      });

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

  app.get("/tenants/:tenant_id/memberships/me", async (req, reply) => {
    const payload = requireAuth(req, reply);
    if (!payload) return;

    const userId = payload.sub;
    const tenantId = req.params.tenant_id;

    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(tenantId)) {
      return reply.code(400).send({ error: "invalid_tenant_id" });
    }

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
}
