// WP-NEXT: split from auth_routes.js (NO BEHAVIOR CHANGE)
import crypto from "node:crypto";
import { readEnvOrFile } from "../../../config.js";

export function oauthCookieOptions() {
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

export function sessionCookieOptions(req) {
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

export function base64Url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

export function sha256Hex(input) {
  return crypto.createHash("sha256").update(String(input)).digest("hex");
}

export function sha256Base64Url(input) {
  return base64Url(crypto.createHash("sha256").update(input).digest());
}

export async function issueRefreshToken(db, { tenantId, userId, rotatedFrom = null }) {
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

export async function revokeRefreshToken(db, raw) {
  if (!raw) return;
  const tokenHash = sha256Hex(raw);
  await db.query("update refresh_tokens set revoked_at = now() where token_hash = $1 and revoked_at is null", [
    tokenHash
  ]);
}

export function isGoogleConfigured() {
  return Boolean(
    readEnvOrFile("GOOGLE_CLIENT_ID") &&
      readEnvOrFile("GOOGLE_CLIENT_SECRET") &&
      readEnvOrFile("GOOGLE_REDIRECT_URI")
  );
}
