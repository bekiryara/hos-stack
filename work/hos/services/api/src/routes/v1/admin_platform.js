import { z } from "zod";
import { audit } from "../../audit.js";
import { requireRole } from "./request_auth.js";

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

function parseLimit(raw, fallback = 50) {
  let limit = Number(raw ?? fallback);
  if (!Number.isFinite(limit)) limit = fallback;
  limit = Math.floor(limit);
  if (limit < 1) limit = 1;
  if (limit > 200) limit = 200;
  return limit;
}

/**
 * Register platform-scoped admin routes.
 * Scope: global visibility across all tenants/worlds for owner/admin roles.
 */
export async function registerV1AdminPlatformRoutes(app, { db }) {
  app.get("/admin/platform/overview", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const [tenants, users, memberships, audit24h] = await Promise.all([
      db.query("select count(*)::int as c from tenants"),
      db.query("select count(*)::int as c from users"),
      db.query("select count(*)::int as c from memberships where status = 'active'"),
      db.query("select count(*)::int as c from audit_events where created_at >= now() - interval '24 hours'")
    ]);

    return reply.send({
      tenants_total: tenants.rows?.[0]?.c ?? 0,
      users_total: users.rows?.[0]?.c ?? 0,
      memberships_active: memberships.rows?.[0]?.c ?? 0,
      audit_events_24h: audit24h.rows?.[0]?.c ?? 0
    });
  });

  app.get("/admin/platform/tenants", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const res = await db.query(
      "select t.id, t.slug, t.name, t.display_name, t.status, t.created_at, count(u.id)::int as users_count from tenants t left join users u on u.tenant_id = t.id group by t.id order by t.created_at asc"
    );
    return reply.send({ items: res.rows });
  });

  app.get("/admin/platform/users", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const res = await db.query(
      "select u.id, u.email, u.role, u.created_at, (u.google_sub is not null) as google_linked, u.tenant_id, t.slug as tenant_slug, t.display_name as tenant_name from users u inner join tenants t on t.id = u.tenant_id order by u.created_at asc"
    );
    return reply.send({ items: res.rows });
  });

  app.get("/admin/platform/memberships", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const res = await db.query(
      "select m.tenant_id, m.user_id, m.role, m.status, m.created_at, m.updated_at, u.email as user_email, u.display_name as user_display_name, t.slug as tenant_slug, t.display_name as tenant_name from memberships m inner join users u on u.id = m.user_id inner join tenants t on t.id = m.tenant_id order by m.created_at asc"
    );
    return reply.send({ items: res.rows });
  });

  app.get("/admin/platform/audit", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const limit = parseLimit(req?.query?.limit, 50);
    const res = await db.query(
      "select a.id, a.action, a.created_at, a.metadata, a.actor_user_id, a.tenant_id, t.slug as tenant_slug from audit_events a left join tenants t on t.id = a.tenant_id order by a.created_at desc limit $1",
      [limit]
    );

    return reply.send({ items: res.rows.map((r) => ({ ...r, metadata: normalizeMetadata(r.metadata) })) });
  });

  const patchUserRoleBody = z.object({
    role: z.enum(["member", "admin", "owner"])
  });

  app.patch("/admin/platform/users/:id/role", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const body = patchUserRoleBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const userId = String(req.params?.id || "");
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });

    const target = await db.query("select id, tenant_id, role from users where id = $1 limit 1", [userId]);
    if (target.rowCount === 0) return reply.code(404).send({ error: "user_not_found" });

    const currentRole = target.rows[0].role ?? "member";
    const targetTenantId = target.rows[0].tenant_id;
    const nextRole = body.data.role;

    if (currentRole === "owner" && nextRole !== "owner") {
      const owners = await db.query(
        "select count(*)::int as c from users where tenant_id = $1 and role = 'owner'",
        [targetTenantId]
      );
      const count = owners.rows?.[0]?.c ?? 0;
      if (count <= 1) return reply.code(409).send({ error: "cannot_remove_last_owner" });
    }

    await db.query("update users set role = $1 where id = $2", [nextRole, userId]);
    await db.query(
      "insert into memberships (tenant_id, user_id, role, status) values ($1, $2, $3, $4) on conflict (tenant_id, user_id) do update set role = $3, status = $4, updated_at = now()",
      [targetTenantId, userId, nextRole, "active"]
    );

    await audit(db, {
      action: "user.role.change.platform",
      tenantId: targetTenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId, role: nextRole, membershipEnsured: true }
    });

    return reply.send({ ok: true });
  });
}
