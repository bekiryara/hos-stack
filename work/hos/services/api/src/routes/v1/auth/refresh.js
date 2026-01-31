// WP-NEXT: split from auth_routes.js (NO BEHAVIOR CHANGE)
import { z } from "zod";
import { signAccessToken } from "../../../auth.js";
import { audit } from "../../../audit.js";
import { sha256Hex, issueRefreshToken, sessionCookieOptions } from "./helpers.js";

const refreshBody = z.object({
  refreshToken: z.string().min(1).optional()
});

export function registerRefresh(app, { db }) {
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
    await db.query("update refresh_tokens set revoked_at = now() where id = $1 and revoked_at is null", [row.id]);

    const next = await issueRefreshToken(db, { tenantId: row.tenant_id, userId: row.user_id, rotatedFrom: row.id });
    reply.setCookie("hos_refresh", next.token, sessionCookieOptions(req));

    const token = signAccessToken({
      sub: row.user_id,
      tenantId: row.tenant_id,
      role: row.role ?? "member"
    });

    await audit(db, { action: "user.token.refresh", tenantId: row.tenant_id, actorUserId: row.user_id });

    return reply.send({ token });
  });
}
