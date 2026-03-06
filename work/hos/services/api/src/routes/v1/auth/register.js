// WP-NEXT: split from auth_routes.js (NO BEHAVIOR CHANGE)
import crypto from "node:crypto";
import { z } from "zod";
import { hashPassword, signAccessToken } from "../../../auth.js";
import { audit } from "../../../audit.js";
import { readEnvOrFile } from "../../../config.js";
import { issueRefreshToken, sessionCookieOptions } from "./helpers.js";

const registerBody = z.object({
  tenantSlug: z.string().min(3).max(50).optional(),
  email: z.string().email(),
  password: z.string().min(8).max(200)
});

export function registerRegister(app, { db }) {
  app.post(
    "/auth/register",
    { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } },
    async (req, reply) => {
      const parsed = registerBody.safeParse(req.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

      const body = parsed.data;
      const DEFAULT_PUBLIC_TENANT_SLUG = readEnvOrFile("DEFAULT_PUBLIC_TENANT_SLUG") || "public";
      const tenantSlug = body.tenantSlug || DEFAULT_PUBLIC_TENANT_SLUG;

      const userId = crypto.randomUUID();
      const passwordHash = hashPassword(body.password);

      if (tenantSlug === DEFAULT_PUBLIC_TENANT_SLUG) {
        let publicTenant = await db.query("select id from tenants where slug = $1 limit 1", [DEFAULT_PUBLIC_TENANT_SLUG]);
        if (publicTenant.rowCount === 0) {
          const publicTenantId = crypto.randomUUID();
          try {
            await db.query(
              "insert into tenants (id, slug, name, display_name) values ($1, $2, $3, $4)",
              [publicTenantId, DEFAULT_PUBLIC_TENANT_SLUG, "Public Customers", "Public Customers"]
            );
            publicTenant = { rowCount: 1, rows: [{ id: publicTenantId }] };
          } catch (e) {
            if (String(e?.code) === "23505") {
              publicTenant = await db.query("select id from tenants where slug = $1 limit 1", [DEFAULT_PUBLIC_TENANT_SLUG]);
            } else {
              throw e;
            }
          }
        }
        const tenantId = publicTenant.rows[0].id;
        const role = "member";

        try {
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
          await db.query(
            "insert into memberships (tenant_id, user_id, role, status) values ($1, $2, $3, $4) on conflict (tenant_id, user_id) do update set role = $3, status = $4",
            [tenantId, userId, role, "active"]
          );
          const token = signAccessToken({ sub: userId, tenantId: null, role });
          return reply.code(201).send({ token });
        } catch (e) {
          if (String(e?.code) === "23505") return reply.code(409).send({ error: "user_conflict" });
          throw e;
        }
      } else {
        const tenant = await db.query("select id from tenants where slug = $1", [tenantSlug]);
        if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });

        const existing = await db.query("select count(*)::int as c from users where tenant_id = $1", [tenant.rows[0].id]);
        const count = existing.rows?.[0]?.c ?? 0;

        if (count > 0) {
          return reply.code(403).send({ error: "registration_closed" });
        }

        const role = "owner";
        const tenantId = tenant.rows[0].id;

        try {
          await db.query(
            "insert into users (id, tenant_id, email, password_hash, role) values ($1, $2, $3, $4, $5)",
            [userId, tenantId, body.email.toLowerCase(), passwordHash, role]
          );
          await db.query(
            "insert into memberships (tenant_id, user_id, role, status) values ($1, $2, $3, $4) on conflict (tenant_id, user_id) do update set role = $3, status = $4",
            [tenantId, userId, role, "active"]
          );
          await audit(db, { action: "user.register", tenantId, actorUserId: userId });
        } catch (e) {
          if (String(e?.code) === "23505") return reply.code(409).send({ error: "user_conflict" });
          throw e;
        }

        const token = signAccessToken({ sub: userId, tenantId, role });
        const refresh = await issueRefreshToken(db, { tenantId, userId });
        reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
        return reply.code(201).send({ token });
      }
    }
  );
}
