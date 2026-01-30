import { verifyAccessToken } from "../../auth.js";

/**
 * Shared request auth helpers for v1 routes that require Bearer token.
 * No behavior change — extracted from auth_me_tenants.js.
 */
export function getBearer(req) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith("Bearer ")) return null;
  return auth.slice("Bearer ".length);
}

export function requireAuth(req, reply) {
  const token = getBearer(req);
  if (!token) {
    reply.code(401).send({ error: "missing_token" });
    return null;
  }

  try {
    const payload = verifyAccessToken(token);
    if (!payload?.sub) {
      reply.code(401).send({ error: "invalid_token" });
      return null;
    }
    return payload;
  } catch {
    reply.code(401).send({ error: "invalid_token" });
    return null;
  }
}

export function requireRole(req, reply, allowedRoles) {
  const payload = requireAuth(req, reply);
  if (!payload) return null;
  const role = payload?.role ?? "member";
  if (!allowedRoles.includes(role)) {
    reply.code(403).send({ error: "forbidden", required: allowedRoles, role });
    return null;
  }
  return payload;
}
