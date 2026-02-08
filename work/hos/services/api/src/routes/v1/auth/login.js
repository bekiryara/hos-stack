// WP-NEXT: split from auth_routes.js (NO BEHAVIOR CHANGE)
import { z } from "zod";
import { signAccessToken, verifyPassword } from "../../../auth.js";
import { audit } from "../../../audit.js";
import { readEnvOrFile } from "../../../config.js";
import { issueRefreshToken, sessionCookieOptions } from "./helpers.js";

const loginBody = z.object({
  tenantSlug: z.string().min(3).max(50).optional(),
  email: z.string().email(),
  password: z.string().min(1).max(200)
});

export function registerLogin(app, { db }) {
  app.post(
    "/auth/login",
    { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } },
    async (req, reply) => {
      const parsed = loginBody.safeParse(req.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

      const body = parsed.data;
      const DEFAULT_PUBLIC_TENANT_SLUG = readEnvOrFile("DEFAULT_PUBLIC_TENANT_SLUG") || "public";
      const tenantSlug = body.tenantSlug || DEFAULT_PUBLIC_TENANT_SLUG;

      if (tenantSlug === DEFAULT_PUBLIC_TENANT_SLUG) {
        // Public customer login MUST be tenant-scoped to avoid cross-tenant ambiguity.
        const publicTenant = await db.query("select id from tenants where slug = $1 limit 1", [
          DEFAULT_PUBLIC_TENANT_SLUG
        ]);
        if (publicTenant.rowCount === 0) {
          // Do not leak whether a public tenant exists.
          return reply.code(401).send({ error: "invalid_credentials" });
        }

        const publicTenantId = publicTenant.rows[0].id;
        const user = await db.query(
          "select id, tenant_id, password_hash, role from users where tenant_id = $1 and email = $2 limit 1",
          [publicTenantId, body.email.toLowerCase()]
        );
        if (user.rowCount === 0) return reply.code(401).send({ error: "invalid_credentials" });
        if (!verifyPassword(body.password, user.rows[0].password_hash)) {
          return reply.code(401).send({ error: "invalid_credentials" });
        }

        const userRow = user.rows[0];
        const token = signAccessToken({
          sub: userRow.id,
          // Public customers are "tenantless" in access token to prevent accidental tenant scoping in downstream worlds.
          tenantId: null,
          role: userRow.role ?? "member"
        });

        // Public customer login does NOT issue refresh cookies (stateless for MVP).
        return reply.send({ token });
      } else {
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
        const refresh = await issueRefreshToken(db, { tenantId: tenant.rows[0].id, userId: user.rows[0].id });
        reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
        await audit(db, { action: "user.login", tenantId: tenant.rows[0].id, actorUserId: user.rows[0].id });
        return reply.send({ token });
      }
    }
  );
}
