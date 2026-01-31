// WP-NEXT: split from auth_routes.js (NO BEHAVIOR CHANGE)
import { revokeRefreshToken, sessionCookieOptions } from "./helpers.js";

export function registerLogout(app, { db }) {
  app.post("/auth/logout", { config: { rateLimit: { max: 60, timeWindow: "1 minute" } } }, async (req, reply) => {
    const raw = req.cookies?.hos_refresh;
    await revokeRefreshToken(db, raw);
    reply.clearCookie("hos_refresh", sessionCookieOptions(req));
    return reply.send({ ok: true });
  });
}
