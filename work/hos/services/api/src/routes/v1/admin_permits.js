import crypto from "node:crypto";
import { z } from "zod";
import { hashPassword } from "../../auth.js";
import { audit } from "../../audit.js";
import { readEnvOrFile } from "../../config.js";
import { requireRole } from "./request_auth.js";
import { createWorldEnforcer } from "../../worlds/enforce_world.js";

/**
 * Register v1 admin, permits, audit, users routes. No behavior change — extracted from app.js.
 */
export async function registerV1AdminPermitRoutes(app, { db, legacy = false }) {
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

  const { enforceWorldOrReply } = createWorldEnforcer();

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

    const tenant = await db.query("select id, slug from tenants where slug = $1 limit 1", [tenantSlug]);
    if (tenant.rowCount === 0) {
      return reply.code(404).send({ error: "tenant_not_found", tenantSlug });
    }
    const tenantId = tenant.rows[0].id;

    const user = await db.query("select id, email from users where email = $1 limit 1", [userEmail]);
    if (user.rowCount === 0) {
      return reply.code(404).send({ error: "user_not_found", userEmail });
    }
    const userId = user.rows[0].id;

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
        if (String(e?.code) !== "23505") throw e;
      }
      tenant = await db.query("select id, slug, name from tenants where slug = $1 limit 1", [tenantSlug]);
    }

    if (tenant.rowCount === 0) return reply.code(500).send({ error: "tenant_upsert_failed" });
    const tenantId = tenant.rows[0].id;

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

      if (String(body.tenant_id) !== String(body.subject_ref.tenant_id)) {
        return reply.code(422).send({ error: "tenant_mismatch" });
      }
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
      const snapshot = typeof permit.snapshot === "string" ? JSON.parse(permit.snapshot) : permit.snapshot;
      const subjectRef = snapshot?.subject_ref ?? null;
      if (!subjectRef || typeof subjectRef !== "object") {
        return reply.code(500).send({ error: "invalid_permit_snapshot", error_subcode: "INVALID_PERMIT_SNAPSHOT" });
      }

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
  }

  const auditQuery = z.object({
    limit: z.coerce.number().int().min(1).max(200).default(50)
  });

  app.get("/audit", async (req, reply) => {
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
