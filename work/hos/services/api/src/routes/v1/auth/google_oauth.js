// WP-NEXT: split from auth_routes.js (NO BEHAVIOR CHANGE)
import crypto from "node:crypto";
import { z } from "zod";
import { hashPassword, signAccessToken } from "../../../auth.js";
import { audit } from "../../../audit.js";
import { readEnvOrFile } from "../../../config.js";
import {
  base64Url,
  sha256Base64Url,
  oauthCookieOptions,
  sessionCookieOptions,
  issueRefreshToken,
  isGoogleConfigured
} from "./helpers.js";

const googleStartQuery = z.object({
  // Optional: if omitted, defaults to public customer login (tenantless token).
  tenantSlug: z.string().min(3).max(50).optional()
});

const googleCallbackQuery = z.object({
  code: z.string().min(1),
  state: z.string().min(1)
});

export function registerGoogleOAuth(app, { db }) {
  app.get("/auth/google/start", async (req, reply) => {
    if (!isGoogleConfigured()) {
      return reply.code(501).send({ error: "google_oauth_not_configured" });
    }

    const parsed = googleStartQuery.safeParse(req.query ?? {});
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const DEFAULT_PUBLIC_TENANT_SLUG = readEnvOrFile("DEFAULT_PUBLIC_TENANT_SLUG") || "public";
    const tenantSlug = String(parsed.data.tenantSlug || DEFAULT_PUBLIC_TENANT_SLUG)
      .toLowerCase()
      .trim();
    const mode = tenantSlug === DEFAULT_PUBLIC_TENANT_SLUG ? "public" : "tenant";

    const tenant = await db.query("select id from tenants where slug = $1 limit 1", [tenantSlug]);
    if (tenant.rowCount === 0) {
      if (mode === "public") {
        // Misconfigured system: public tenant missing.
        return reply.code(501).send({ error: "public_tenant_not_configured" });
      }
      return reply.code(404).send({ error: "tenant_not_found" });
    }

    const state = crypto.randomUUID();
    const verifier = base64Url(crypto.randomBytes(32));
    const challenge = sha256Base64Url(verifier);

    const cookieOpts = oauthCookieOptions();

    reply.setCookie("hos_oauth_state", state, cookieOpts);
    reply.setCookie("hos_oauth_verifier", verifier, cookieOpts);
    reply.setCookie("hos_oauth_tenant", tenantSlug, cookieOpts);
    reply.setCookie("hos_oauth_mode", mode, cookieOpts);

    const params = new URLSearchParams({
      client_id: readEnvOrFile("GOOGLE_CLIENT_ID"),
      redirect_uri: readEnvOrFile("GOOGLE_REDIRECT_URI"),
      response_type: "code",
      scope: "openid email profile",
      state,
      code_challenge: challenge,
      code_challenge_method: "S256",
      prompt: "select_account"
    });

    return reply.redirect(`https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`);
  });

  app.get("/auth/google/callback", async (req, reply) => {
    const accept = String(req.headers.accept || "");
    const wantsHtml = accept.includes("text/html");
    const marketplaceBase =
      String(readEnvOrFile("MARKETPLACE_WEB_PUBLIC_URL") || "http://localhost:3002/marketplace").replace(/\/+$/, "");

    function redirectToMarketplaceLogin(reason, extra = {}) {
      const qs = new URLSearchParams({ reason, ...extra });
      return reply.redirect(`${marketplaceBase}/login?${qs.toString()}`);
    }

    if (!isGoogleConfigured()) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_not_configured");
      return reply.code(501).send({ error: "google_oauth_not_configured" });
    }

    const parsed = googleCallbackQuery.safeParse(req.query ?? {});
    if (!parsed.success) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_invalid_callback");
      return reply.code(400).send({ error: parsed.error.flatten() });
    }

    const expectedState = req.cookies?.hos_oauth_state;
    const verifier = req.cookies?.hos_oauth_verifier;
    const tenantSlug = req.cookies?.hos_oauth_tenant;
    const modeCookie = req.cookies?.hos_oauth_mode;

    if (!expectedState || !verifier || !tenantSlug) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_state_missing");
      return reply.code(401).send({ error: "oauth_state_missing" });
    }
    if (parsed.data.state !== expectedState) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_state_mismatch");
      return reply.code(401).send({ error: "oauth_state_mismatch" });
    }

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code: parsed.data.code,
        client_id: readEnvOrFile("GOOGLE_CLIENT_ID"),
        client_secret: readEnvOrFile("GOOGLE_CLIENT_SECRET"),
        redirect_uri: readEnvOrFile("GOOGLE_REDIRECT_URI"),
        grant_type: "authorization_code",
        code_verifier: verifier
      })
    });

    if (!tokenRes.ok) {
      const txt = await tokenRes.text().catch(() => "");
      if (wantsHtml) return redirectToMarketplaceLogin("google_token_exchange_failed");
      return reply.code(401).send({ error: "oauth_token_exchange_failed", detail: txt.slice(0, 500) });
    }

    const tokenJson = await tokenRes.json();
    const idToken = tokenJson?.id_token;
    if (!idToken) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_missing_id_token");
      return reply.code(401).send({ error: "missing_id_token" });
    }

    const infoRes = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
    );
    if (!infoRes.ok) {
      const txt = await infoRes.text().catch(() => "");
      if (wantsHtml) return redirectToMarketplaceLogin("google_invalid_token");
      return reply.code(401).send({ error: "invalid_google_token", detail: txt.slice(0, 500) });
    }
    const info = await infoRes.json();
    const googleSub = String(info?.sub ?? "");
    const email = String(info?.email ?? "").toLowerCase();
    const emailVerified = String(info?.email_verified ?? "") === "true";
    const aud = String(info?.aud ?? "");

    if (!googleSub || !email) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_invalid_claims");
      return reply.code(401).send({ error: "invalid_google_claims" });
    }
    if (aud !== readEnvOrFile("GOOGLE_CLIENT_ID")) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_invalid_audience");
      return reply.code(401).send({ error: "invalid_google_audience" });
    }
    if (!emailVerified) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_email_not_verified");
      return reply.code(401).send({ error: "email_not_verified" });
    }

    const DEFAULT_PUBLIC_TENANT_SLUG = readEnvOrFile("DEFAULT_PUBLIC_TENANT_SLUG") || "public";
    const effectiveMode =
      modeCookie === "public" || modeCookie === "tenant"
        ? modeCookie
        : String(tenantSlug).toLowerCase() === DEFAULT_PUBLIC_TENANT_SLUG
          ? "public"
          : "tenant";

    const tenant = await db.query("select id from tenants where slug = $1 limit 1", [tenantSlug]);
    if (tenant.rowCount === 0) {
      if (wantsHtml) return redirectToMarketplaceLogin("google_tenant_not_found");
      return reply.code(404).send({ error: "tenant_not_found" });
    }
    const tenantId = tenant.rows[0].id;

    let user = await db.query(
      "select id, role from users where tenant_id = $1 and google_sub = $2",
      [tenantId, googleSub]
    );

    if (user.rowCount === 0) {
      const byEmail = await db.query("select id, role from users where tenant_id = $1 and email = $2", [
        tenantId,
        email
      ]);
      if (byEmail.rowCount > 0) {
        await db.query("update users set google_sub = $1 where id = $2", [googleSub, byEmail.rows[0].id]);
        user = byEmail;
      } else {
        const userId = crypto.randomUUID();
        const passwordHash = hashPassword(base64Url(crypto.randomBytes(24)));
        const role = "member";
        await db.query(
          "insert into users (id, tenant_id, email, password_hash, role, google_sub) values ($1, $2, $3, $4, $5, $6)",
          [userId, tenantId, email, passwordHash, role, googleSub]
        );
        user = { rowCount: 1, rows: [{ id: userId, role }] };
      }
    }

    const role = user.rows[0].role ?? "member";
    const userId = user.rows[0].id;
    const token =
      effectiveMode === "public"
        ? signAccessToken({ sub: userId, tenantId: null, role })
        : signAccessToken({ sub: userId, tenantId, role });

    if (effectiveMode !== "public") {
      const refresh = await issueRefreshToken(db, { tenantId, userId });
      reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
    }

    await audit(db, { action: "user.login.google", tenantId, actorUserId: userId });

    const cookieOpts = oauthCookieOptions();
    reply.clearCookie("hos_oauth_state", cookieOpts);
    reply.clearCookie("hos_oauth_verifier", cookieOpts);
    reply.clearCookie("hos_oauth_tenant", cookieOpts);
    reply.clearCookie("hos_oauth_mode", cookieOpts);

    if (wantsHtml) {
      // Standard UX: send user back to Marketplace to store session token.
      // Put token in URL fragment (not query) to avoid server logs.
      const fragment = `token=${encodeURIComponent(token)}`;
      return reply.redirect(`${marketplaceBase}/oauth/complete#${fragment}`);
    }

    return reply.send({ token });
  });
}
