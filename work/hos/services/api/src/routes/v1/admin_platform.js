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

function parseOffset(raw) {
  let offset = Number(raw ?? 0);
  if (!Number.isFinite(offset)) offset = 0;
  offset = Math.floor(offset);
  if (offset < 0) offset = 0;
  if (offset > 100000) offset = 100000;
  return offset;
}

function parseIsoDate(raw) {
  if (!raw) return null;
  const d = new Date(String(raw));
  return Number.isFinite(d.getTime()) ? d.toISOString() : null;
}

function parseLikeTokens(raw) {
  return String(raw || "")
    .toLowerCase()
    .split(/[\s|,;]+/)
    .map((x) => x.trim())
    .filter(Boolean)
    .slice(0, 8);
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

  const patchMembershipBody = z
    .object({
      role: z.enum(["member", "admin", "owner"]).optional(),
      status: z.enum(["active", "inactive", "suspended"]).optional()
    })
    .refine((v) => v.role !== undefined || v.status !== undefined, {
      message: "role_or_status_required"
    });
  const membershipLifecycleBody = z.object({
    action: z.enum(["deactivate", "delete"])
  });

  app.patch("/admin/platform/memberships/:tenantId/:userId", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const tenantId = String(req.params?.tenantId || "");
    const userId = String(req.params?.userId || "");
    if (!tenantId) return reply.code(400).send({ error: "invalid_tenant_id" });
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });

    const body = patchMembershipBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const currentRes = await db.query(
      "select tenant_id, user_id, role, status from memberships where tenant_id = $1 and user_id = $2 limit 1",
      [tenantId, userId]
    );
    if (currentRes.rowCount === 0) return reply.code(404).send({ error: "membership_not_found" });

    const current = currentRes.rows[0];
    const nextRole = body.data.role ?? current.role;
    const nextStatus = body.data.status ?? current.status;

    if (current.role === "owner" && current.status === "active" && (nextRole !== "owner" || nextStatus !== "active")) {
      const owners = await db.query(
        "select count(*)::int as c from memberships where tenant_id = $1 and role = 'owner' and status = 'active'",
        [tenantId]
      );
      const count = owners.rows?.[0]?.c ?? 0;
      if (count <= 1) {
        return reply.code(409).send({ error: "cannot_remove_last_owner" });
      }
    }

    await db.query(
      "update memberships set role = $1, status = $2, updated_at = now() where tenant_id = $3 and user_id = $4",
      [nextRole, nextStatus, tenantId, userId]
    );

    if (body.data.role !== undefined) {
      await db.query("update users set role = $1 where tenant_id = $2 and id = $3", [nextRole, tenantId, userId]);
    }

    await audit(db, {
      action: "membership.update.platform",
      tenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId, role: nextRole, status: nextStatus }
    });

    return reply.send({ ok: true, item: { tenant_id: tenantId, user_id: userId, role: nextRole, status: nextStatus } });
  });

  app.post("/admin/platform/memberships/:tenantId/:userId/lifecycle", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const tenantId = String(req.params?.tenantId || "");
    const userId = String(req.params?.userId || "");
    if (!tenantId) return reply.code(400).send({ error: "invalid_tenant_id" });
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });

    const body = membershipLifecycleBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const currentRes = await db.query(
      "select tenant_id, user_id, role, status from memberships where tenant_id = $1 and user_id = $2 limit 1",
      [tenantId, userId]
    );
    if (currentRes.rowCount === 0) return reply.code(404).send({ error: "membership_not_found" });

    const current = currentRes.rows[0];
    const isOwnerActive = current.role === "owner" && current.status === "active";
    if (isOwnerActive) {
      const owners = await db.query(
        "select count(*)::int as c from memberships where tenant_id = $1 and role = 'owner' and status = 'active'",
        [tenantId]
      );
      const count = owners.rows?.[0]?.c ?? 0;
      if (count <= 1) return reply.code(409).send({ error: "cannot_remove_last_owner" });
    }

    if (body.data.action === "deactivate") {
      await db.query(
        "update memberships set status = 'inactive', updated_at = now() where tenant_id = $1 and user_id = $2",
        [tenantId, userId]
      );
      await db.query(
        "update users set role = 'member' where id = $1 and tenant_id = $2 and role <> 'member'",
        [userId, tenantId]
      );
      await audit(db, {
        action: "membership.deactivate.platform",
        tenantId,
        actorUserId: payload.sub,
        metadata: { targetUserId: userId }
      });
      return reply.send({ ok: true, action: "deactivate" });
    }

    await db.query("delete from memberships where tenant_id = $1 and user_id = $2", [tenantId, userId]);
    await db.query(
      "update users set role = 'member' where id = $1 and tenant_id = $2 and role <> 'member'",
      [userId, tenantId]
    );
    await audit(db, {
      action: "membership.delete.platform",
      tenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId }
    });
    return reply.send({ ok: true, action: "delete" });
  });

  app.get("/admin/platform/audit", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner", "admin"]);
    if (!payload) return;

    const limit = parseLimit(req?.query?.limit, 50);
    const offset = parseOffset(req?.query?.offset);
    const actionTokens = parseLikeTokens(req?.query?.action);
    const actorLike = String(req?.query?.actor || "").trim().toLowerCase();
    const tenantLike = String(req?.query?.tenant || "").trim().toLowerCase();
    const qTokens = parseLikeTokens(req?.query?.q);
    const fromIso = parseIsoDate(req?.query?.from);
    const toIso = parseIsoDate(req?.query?.to);

    const where = [];
    const params = [];
    let i = 1;

    if (actionTokens.length > 0) {
      const parts = actionTokens.map((tok) => {
        const p = `$${i++}`;
        params.push(`%${tok}%`);
        return `lower(a.action) like ${p}`;
      });
      where.push(`(${parts.join(" or ")})`);
    }
    if (actorLike) {
      where.push(`lower(coalesce(a.actor_user_id::text,'')) like $${i++}`);
      params.push(`%${actorLike}%`);
    }
    if (tenantLike) {
      where.push(`lower(coalesce(t.slug,'')) like $${i++}`);
      params.push(`%${tenantLike}%`);
    }
    if (fromIso) {
      where.push(`a.created_at >= $${i++}`);
      params.push(fromIso);
    }
    if (toIso) {
      where.push(`a.created_at <= $${i++}`);
      params.push(toIso);
    }
    if (qTokens.length > 0) {
      const qParts = qTokens.map((tok) => {
        const p = `$${i++}`;
        params.push(`%${tok}%`);
        return `(lower(coalesce(a.action,'')) like ${p} or lower(coalesce(a.actor_user_id::text,'')) like ${p} or lower(coalesce(au.email,'')) like ${p} or lower(coalesce(t.slug,'')) like ${p})`;
      });
      where.push(`(${qParts.join(" or ")})`);
    }

    params.push(limit);
    params.push(offset);
    const whereSql = where.length > 0 ? `where ${where.join(" and ")}` : "";
    const sql = `select a.id, a.action, a.created_at, a.metadata, a.actor_user_id, au.email as actor_email, a.tenant_id, t.slug as tenant_slug from audit_events a left join tenants t on t.id = a.tenant_id left join users au on au.id = a.actor_user_id ${whereSql} order by a.created_at desc limit $${i} offset $${i + 1}`;
    const res = await db.query(sql, params);

    return reply.send({ items: res.rows.map((r) => ({ ...r, metadata: normalizeMetadata(r.metadata) })) });
  });

  const patchUserRoleBody = z.object({
    role: z.enum(["member", "admin", "owner"])
  });
  const userLifecycleBody = z.object({
    action: z.enum(["deactivate", "delete"])
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

  app.post("/admin/platform/users/:id/lifecycle", async (req, reply) => {
    const payload = requireRole(req, reply, ["owner"]);
    if (!payload) return;

    const body = userLifecycleBody.safeParse(req.body);
    if (!body.success) return reply.code(400).send({ error: body.error.flatten() });

    const userId = String(req.params?.id || "");
    if (!userId) return reply.code(400).send({ error: "invalid_user_id" });
    if (userId === String(payload.sub || "")) return reply.code(409).send({ error: "cannot_delete_current_admin_session" });

    const target = await db.query("select id, tenant_id, email, role from users where id = $1 limit 1", [userId]);
    if (target.rowCount === 0) return reply.code(404).send({ error: "user_not_found" });
    const targetTenantId = target.rows[0].tenant_id;
    const targetEmail = target.rows[0].email;

    const lockedOwner = await db.query(
      "select m.tenant_id from memberships m where m.user_id = $1 and m.role = 'owner' and m.status = 'active' and (select count(*)::int from memberships mo where mo.tenant_id = m.tenant_id and mo.role = 'owner' and mo.status = 'active') <= 1 limit 1",
      [userId]
    );
    if (lockedOwner.rowCount > 0) return reply.code(409).send({ error: "cannot_remove_last_owner" });

    if (body.data.action === "deactivate") {
      const disabledMemberships = await db.query(
        "update memberships set status = 'inactive', updated_at = now() where user_id = $1 and status = 'active'",
        [userId]
      );
      await db.query("update users set role = 'member' where id = $1 and role <> 'member'", [userId]);

      await audit(db, {
        action: "user.deactivate.platform",
        tenantId: targetTenantId,
        actorUserId: payload.sub,
        metadata: { targetUserId: userId, targetEmail, activeMembershipsDisabled: disabledMemberships.rowCount ?? 0 }
      });

      return reply.send({ ok: true, action: "deactivate", active_memberships_disabled: disabledMemberships.rowCount ?? 0 });
    }

    const permitRefs = await db.query("select count(*)::int as c from hos_permits where actor_id = $1", [userId]);
    const permitCount = permitRefs.rows?.[0]?.c ?? 0;
    if (permitCount > 0) {
      return reply.code(409).send({ error: "cannot_delete_user_with_permits", permits_count: permitCount });
    }

    await db.query("begin");
    try {
      const del = await db.query("delete from users where id = $1", [userId]);
      if (del.rowCount === 0) {
        await db.query("rollback");
        return reply.code(404).send({ error: "user_not_found" });
      }
      await db.query("commit");
    } catch (e) {
      await db.query("rollback");
      throw e;
    }

    await audit(db, {
      action: "user.delete.platform",
      tenantId: targetTenantId,
      actorUserId: payload.sub,
      metadata: { targetUserId: userId, targetEmail }
    });

    return reply.send({ ok: true, action: "delete" });
  });
}
