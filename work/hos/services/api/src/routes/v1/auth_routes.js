import crypto from "node:crypto";
import { z } from "zod";
import { hashPassword, signAccessToken, verifyPassword } from "../../auth.js";
import { audit } from "../../audit.js";
import { readEnvOrFile } from "../../config.js";

/**
 * Register v1 auth routes (register, login, refresh, logout, Google OAuth). No behavior change — split from auth_me_tenants.js.
 */
export async function registerV1AuthRoutes(app, { db }) {
  function oauthCookieOptions() {
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

  function sessionCookieOptions(req) {
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

  async function issueRefreshToken({ tenantId, userId, rotatedFrom = null }) {
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

  async function revokeRefreshToken(raw) {
    if (!raw) return;
    const tokenHash = sha256Hex(raw);
    await db.query("update refresh_tokens set revoked_at = now() where token_hash = $1 and revoked_at is null", [
      tokenHash
    ]);
  }

  const registerBody = z.object({
    tenantSlug: z.string().min(3).max(50).optional(),
    email: z.string().email(),
    password: z.string().min(8).max(200)
  });

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
          const token = signAccessToken({ sub: userId, tenantId: null, role });
          return reply.code(201).send({ token });
        } catch (e) {
          if (String(e?.code) === "23505") return reply.code(409).send({ error: "user_conflict" });
          throw e;
        }
      } else {
        const tenant = await db.query("select id from tenants where slug = $1", [tenantSlug]);
        if (tenant.rowCount === 0) return reply.code(404).send({ error: "tenant_not_found" });

        const tenantId = tenant.rows[0].id;
        const existing = await db.query("select count(*)::int as c from users where tenant_id = $1", [tenantId]);
        const count = existing.rows?.[0]?.c ?? 0;

        if (count > 0) {
          return reply.code(403).send({ error: "registration_closed" });
        }

        const role = "owner";

        try {
          await db.query(
            "insert into users (id, tenant_id, email, password_hash, role) values ($1, $2, $3, $4, $5)",
            [userId, tenantId, body.email.toLowerCase(), passwordHash, role]
          );
          await audit(db, { action: "user.register", tenantId, actorUserId: userId });
        } catch (e) {
          if (String(e?.code) === "23505") return reply.code(409).send({ error: "user_conflict" });
          throw e;
        }

        const token = signAccessToken({ sub: userId, tenantId, role });
        const refresh = await issueRefreshToken({ tenantId, userId });
        reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
        return reply.code(201).send({ token });
      }
    }
  );

  const loginBody = z.object({
    tenantSlug: z.string().min(3).max(50).optional(),
    email: z.string().email(),
    password: z.string().min(1).max(200)
  });

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
        const user = await db.query(
          "select id, tenant_id, password_hash, role from users where email = $1 limit 1",
          [body.email.toLowerCase()]
        );
        if (user.rowCount === 0) return reply.code(401).send({ error: "invalid_credentials" });
        if (!verifyPassword(body.password, user.rows[0].password_hash))
          return reply.code(401).send({ error: "invalid_credentials" });

        const userRow = user.rows[0];
        const publicTenant = await db.query("select id from tenants where slug = $1 limit 1", [DEFAULT_PUBLIC_TENANT_SLUG]);
        const isPublicCustomer = publicTenant.rowCount > 0 && userRow.tenant_id === publicTenant.rows[0].id;

        const token = signAccessToken({
          sub: userRow.id,
          tenantId: isPublicCustomer ? null : userRow.tenant_id,
          role: userRow.role ?? "member"
        });
        if (!isPublicCustomer) {
          const refresh = await issueRefreshToken({ tenantId: userRow.tenant_id, userId: userRow.id });
          reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
          await audit(db, { action: "user.login", tenantId: userRow.tenant_id, actorUserId: userRow.id });
        }
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
        const refresh = await issueRefreshToken({ tenantId: tenant.rows[0].id, userId: user.rows[0].id });
        reply.setCookie("hos_refresh", refresh.token, sessionCookieOptions(req));
        await audit(db, { action: "user.login", tenantId: tenant.rows[0].id, actorUserId: user.rows[0].id });
        return reply.send({ token });
      }
    }
  );

  const refreshBody = z.object({
    refreshToken: z.string().min(1).optional()
  });

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

    const next = await issueRefreshToken({ tenantId: row.tenant_id, userId: row.user_id, rotatedFrom: row.id });
    reply.setCookie("hos_refresh", next.token, sessionCookieOptions(req));

    const token = signAccessToken({
      sub: row.user_id,
      tenantId: row.tenant_id,
      role: row.role ?? "member"
    });

    await audit(db, { action: "user.token.refresh", tenantId: row.tenant_id, actorUserId: row.user_id });

    return reply.send({ token });
  });

  app.post("/auth/logout", { config: { rateLimit: { max: 60, timeWindow: "1 minute" } } }, async (req, reply) => {
    const raw = req.cookies?.hos_refresh;
    await revokeRefreshToken(raw);
    reply.clearCookie("hos_refresh", sessionCookieOptions(req));
    return reply.send({ ok: true });
  });

  function sha256Base64Url(input) {
    return base64Url(crypto.createHash("sha256").update(input).digest());
  }

  function isGoogleConfigured() {
    return Boolean(
      readEnvOrFile("GOOGLE_CLIENT_ID") &&
        readEnvOrFile("GOOGLE_CLIENT_SECRET") &&
        readEnvOrFile("GOOGLE_REDIRECT_URI")
    );
  }

  const googleStartQuery = z.object({
    tenantSlug: z.string().min(3).max(50)
  });

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

  const googleCallbackQuery = z.object({
    code: z.string().min(1),
    state: z.string().min(1)
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
    const refresh = await issueRefreshToken({ tenantId, userId: user.rows[0].id });
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
