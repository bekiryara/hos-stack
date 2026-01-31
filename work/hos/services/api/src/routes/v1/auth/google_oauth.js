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
  tenantSlug: z.string().min(3).max(50)
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

    const tenant = await db.query("select id from tenants where slug = $1", [parsed.data.tenantSlug]);
    if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });

    const state = crypto.randomUUID();
    const verifier = base64Url(crypto.randomBytes(32));
    const challenge = sha256Base64Url(verifier);

    const cookieOpts = oauthCookieOptions();

    reply.setCookie("hos_oauth_state", state, cookieOpts);
    reply.setCookie("hos_oauth_verifier", verifier, cookieOpts);
    reply.setCookie("hos_oauth_tenant", parsed.data.tenantSlug, cookieOpts);

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
    if (!isGoogleConfigured()) {
      return reply.code(501).send({ error: "google_oauth_not_configured" });
    }

    const parsed = googleCallbackQuery.safeParse(req.query ?? {});
    if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

    const expectedState = req.cookies?.hos_oauth_state;
    const verifier = req.cookies?.hos_oauth_verifier;
    const tenantSlug = req.cookies?.hos_oauth_tenant;

    if (!expectedState || !verifier || !tenantSlug) {
      return reply.code(401).send({ error: "oauth_state_missing" });
    }
    if (parsed.data.state !== expectedState) {
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
      return reply.code(401).send({ error: "oauth_token_exchange_failed", detail: txt.slice(0, 500) });
    }

    const tokenJson = await tokenRes.json();
    const idToken = tokenJson?.id_token;
    if (!idToken) return reply.code(401).send({ error: "missing_id_token" });

    const infoRes = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
    );
    if (!infoRes.ok) {
      const txt = await infoRes.text().catch(() => "");
      return reply.code(401).send({ error: "invalid_google_token", detail: txt.slice(0, 500) });
    }
    const info = await infoRes.json();
    const googleSub = String(info?.sub ?? "");
    const email = String(info?.email ?? "").toLowerCase();
    const emailVerified = String(info?.email_verified ?? "") === "true";
    const aud = String(info?.aud ?? "");

    if (!googleSub || !email) return reply.code(401).send({ error: "invalid_google_claims" });
    if (aud !== readEnvOrFile("GOOGLE_CLIENT_ID")) return reply.code(401).send({ error: "invalid_google_audience" });
    if (!emailVerified) return reply.code(401).send({ error: "email_not_verified" });

    const tenant = await db.query("select id from tenants where slug = $1", [tenantSlug]);
    if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });
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

    const token = signAccessToken({ sub: user.rows[0].id, tenantId, role: user.rows[0].role ?? "member" });
    const refresh = await issueRefreshToken(db, { tenantId, userId: user.rows[0].id });
    reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
    await audit(db, { action: "user.login.google", tenantId, actorUserId: user.rows[0].id });

    const cookieOpts = oauthCookieOptions();
    reply.clearCookie("hos_oauth_state", cookieOpts);
    reply.clearCookie("hos_oauth_verifier", cookieOpts);
    reply.clearCookie("hos_oauth_tenant", cookieOpts);

    const accept = String(req.headers.accept || "");
    if (accept.includes("text/html")) {
      reply.header("content-type", "text/html; charset=utf-8");
      reply.header("cache-control", "no-store");
      return reply.send(`<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>H-OS Login</title></head>
  <body style="font-family:system-ui,Segoe UI,Arial,sans-serif;padding:24px;max-width:900px">
    <h2>Login OK</h2>
    <p>JWT token:</p>
    <textarea style="width:100%;height:140px" readonly>${token}</textarea>
    <p>Test:</p>
    <pre>curl -H "Authorization: Bearer &lt;token&gt;" http://localhost:3000/v1/me</pre>
  </body>
</html>`);
    }

    return reply.send({ token });
  });
}
