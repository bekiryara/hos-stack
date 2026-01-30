import crypto from "node:crypto";
import { z } from "zod";
import jwt from "jsonwebtoken";
import { verifyPassword, signAccessToken, verifyAccessToken } from "../auth.js";

function base64Url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function sha256Base64Url(input) {
  return base64Url(crypto.createHash("sha256").update(String(input)).digest());
}

function publicIssuerFromReq(req) {
  const envIssuer = String(process.env.HOS_PUBLIC_ISSUER ?? "").trim();
  if (envIssuer) return envIssuer.replace(/\/+$/, "");

  const xfProto = String(req.headers["x-forwarded-proto"] ?? "").split(",")[0]?.trim();
  const xfHost = String(req.headers["x-forwarded-host"] ?? "").split(",")[0]?.trim();
  const proto = xfProto || "http";
  const host = xfHost || String(req.headers.host ?? "");
  return `${proto}://${host}`.replace(/\/+$/, "");
}

async function ensureOidcSigningKey(db) {
  const existing = await db.query(
    "select kid, public_jwk, private_pem from hos_oidc_keys where is_active = true order by created_at desc limit 1"
  );
  if (existing.rowCount > 0) {
    const row = existing.rows[0];
    return {
      kid: String(row.kid),
      publicJwk: typeof row.public_jwk === "string" ? JSON.parse(row.public_jwk) : row.public_jwk,
      privatePem: String(row.private_pem)
    };
  }

  const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
  const kid = crypto.randomUUID();
  const publicJwk = publicKey.export({ format: "jwk" });
  publicJwk.use = "sig";
  publicJwk.alg = "RS256";
  publicJwk.kid = kid;

  const privatePem = privateKey.export({ format: "pem", type: "pkcs8" });

  await db.query(
    "insert into hos_oidc_keys (id, kid, alg, public_jwk, private_pem, is_active) values ($1,$2,$3,$4,$5,true)",
    [crypto.randomUUID(), kid, "RS256", JSON.stringify(publicJwk), String(privatePem)]
  );

  return { kid, publicJwk, privatePem: String(privatePem) };
}

async function getOrProvisionOidcClient(db, { clientId, redirectUri }) {
  const found = await db.query(
    "select id, client_id, redirect_uris from hos_oidc_clients where client_id = $1 limit 1",
    [clientId]
  );
  if (found.rowCount === 0) {
    const isLocalRedirect = /^https?:\/\/localhost(\/|:)/i.test(String(redirectUri));
    if (clientId !== "pazar-client" || !isLocalRedirect) return null;
    const id = crypto.randomUUID();
    await db.query(
      "insert into hos_oidc_clients (id, client_id, redirect_uris, allowed_worlds) values ($1,$2,$3,$4)",
      [id, clientId, JSON.stringify([redirectUri]), JSON.stringify([])]
    );
    return { id, clientId, redirectUris: [redirectUri] };
  }

  const row = found.rows[0];
  const redirectUris = typeof row.redirect_uris === "string" ? JSON.parse(row.redirect_uris) : row.redirect_uris;
  return {
    id: String(row.id),
    clientId: String(row.client_id),
    redirectUris: Array.isArray(redirectUris) ? redirectUris : []
  };
}

/**
 * Register OIDC public (ROOT, unversioned) routes: /jwks.json, /authorize, /oidc/authorize, /token, /userinfo.
 * No behavior change — extracted from app.js.
 */
export async function registerOidcPublicRoutes(app, { db }) {
  app.get("/jwks.json", async (_req, reply) => {
    const key = await ensureOidcSigningKey(db);
    return reply.send({ keys: [key.publicJwk] });
  });

  app.get("/authorize", async (req, reply) => {
    const q = req.query ?? {};
    const responseType = String(q.response_type ?? "");
    const clientId = String(q.client_id ?? "");
    const redirectUri = String(q.redirect_uri ?? "");
    const scope = String(q.scope ?? "openid");
    const state = String(q.state ?? "");
    const codeChallenge = String(q.code_challenge ?? "");
    const codeChallengeMethod = String(q.code_challenge_method ?? "");
    const world = String(q.world ?? "");

    if (responseType !== "code") return reply.code(400).send({ error: "unsupported_response_type" });
    if (!clientId || !redirectUri) return reply.code(400).send({ error: "invalid_request" });
    if (!state) return reply.code(400).send({ error: "invalid_request", error_description: "missing_state" });
    if (!codeChallenge || codeChallengeMethod !== "S256")
      return reply.code(400).send({ error: "invalid_request", error_description: "pkce_required" });
    if (!world) return reply.code(400).send({ error: "missing_world" });

    const client = await getOrProvisionOidcClient(db, { clientId, redirectUri });
    if (!client) return reply.code(400).send({ error: "invalid_client" });
    if (!client.redirectUris.includes(redirectUri))
      return reply.code(400).send({ error: "invalid_request", error_description: "redirect_uri_not_allowed" });

    const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>H-OS Authorize</title>
  <style>
    body{font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif;margin:24px;max-width:720px}
    .box{border:1px solid #ddd;border-radius:10px;padding:16px}
    label{display:block;margin-top:10px;font-weight:600}
    input{width:100%;padding:10px;border:1px solid #ccc;border-radius:8px;margin-top:6px}
    button{margin-top:14px;padding:10px 14px;border:0;border-radius:8px;background:#111;color:#fff;cursor:pointer}
    .muted{color:#666;font-size:12px;margin-top:8px}
    .err{color:#b00020;margin-top:10px}
  </style>
</head>
<body>
  <h2>H-OS Login (SSO)</h2>
  <div class="box">
    <div id="err" class="err" style="display:none"></div>
    <label>Tenant Slug</label>
    <input id="tenantSlug" placeholder="demo" autocomplete="organization"/>
    <label>Email</label>
    <input id="email" placeholder="you@example.com" autocomplete="email"/>
    <label>Password</label>
    <input id="password" type="password" autocomplete="current-password"/>
    <button id="btn">Sign in</button>
    <div class="muted">Client: ${clientId} · World: ${world}</div>
  </div>
  <script>
    const payload = ${JSON.stringify({
      response_type: responseType,
      client_id: clientId,
      redirect_uri: redirectUri,
      scope,
      state,
      code_challenge: codeChallenge,
      code_challenge_method: codeChallengeMethod,
      world
    })};
    const errEl = document.getElementById('err');
    function showErr(msg){ errEl.textContent = msg; errEl.style.display = 'block'; }
    document.getElementById('btn').addEventListener('click', async () => {
      errEl.style.display = 'none';
      const tenantSlug = document.getElementById('tenantSlug').value.trim();
      const email = document.getElementById('email').value.trim();
      const password = document.getElementById('password').value;
      if(!tenantSlug || !email || !password){ showErr('Missing tenant/email/password'); return; }
      const res = await fetch('/oidc/authorize', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ tenantSlug, email, password, ...payload })
      });
      const json = await res.json().catch(() => ({}));
      if(!res.ok){ showErr(json.error_description || json.error || ('authorize_failed_'+res.status)); return; }
      if(!json.redirect_to){ showErr('missing redirect_to'); return; }
      window.location.assign(json.redirect_to);
    });
  </script>
</body>
</html>`;

    reply.header("content-type", "text/html; charset=utf-8");
    return reply.send(html);
  });

  const oidcAuthorizeBody = z.object({
    tenantSlug: z.string().min(1),
    email: z.string().email(),
    password: z.string().min(1),
    response_type: z.literal("code"),
    client_id: z.string().min(1),
    redirect_uri: z.string().min(1),
    scope: z.string().min(1).optional(),
    state: z.string().min(1),
    code_challenge: z.string().min(20),
    code_challenge_method: z.literal("S256"),
    world: z.string().min(1)
  });

  app.post("/oidc/authorize", async (req, reply) => {
    const parsed = oidcAuthorizeBody.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: "invalid_request", details: parsed.error.flatten() });
    const body = parsed.data;

    const client = await getOrProvisionOidcClient(db, { clientId: body.client_id, redirectUri: body.redirect_uri });
    if (!client) return reply.code(400).send({ error: "invalid_client" });
    if (!client.redirectUris.includes(body.redirect_uri))
      return reply.code(400).send({ error: "invalid_request", error_description: "redirect_uri_not_allowed" });

    const tenant = await db.query("select id from tenants where slug = $1", [body.tenantSlug]);
    if (tenant.rowCount === 0)
      return reply.code(401).send({ error: "access_denied", error_description: "tenant_not_found" });

    const user = await db.query(
      "select id, password_hash, role from users where tenant_id = $1 and email = $2",
      [tenant.rows[0].id, body.email.toLowerCase()]
    );
    if (user.rowCount === 0) return reply.code(401).send({ error: "access_denied", error_description: "invalid_credentials" });
    if (!verifyPassword(body.password, user.rows[0].password_hash))
      return reply.code(401).send({ error: "access_denied", error_description: "invalid_credentials" });

    const code = base64Url(crypto.randomBytes(32));
    const expiresAt = new Date(Date.now() + 1000 * 60 * 5);

    await db.query(
      `insert into hos_oidc_auth_codes
        (code, client_id, redirect_uri, tenant_id, user_id, scope, world, code_challenge, code_challenge_method, expires_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [
        code,
        body.client_id,
        body.redirect_uri,
        tenant.rows[0].id,
        user.rows[0].id,
        String(body.scope ?? "openid profile email"),
        body.world,
        body.code_challenge,
        body.code_challenge_method,
        expiresAt.toISOString()
      ]
    );

    const sep = body.redirect_uri.includes("?") ? "&" : "?";
    const redirectTo = `${body.redirect_uri}${sep}code=${encodeURIComponent(code)}&state=${encodeURIComponent(body.state)}`;
    return reply.send({ redirect_to: redirectTo });
  });

  const tokenBody = z.object({
    grant_type: z.literal("authorization_code"),
    client_id: z.string().min(1),
    redirect_uri: z.string().min(1),
    code: z.string().min(8),
    code_verifier: z.string().min(20)
  });

  app.post("/token", async (req, reply) => {
    const parsed = tokenBody.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: "invalid_request", details: parsed.error.flatten() });
    const body = parsed.data;

    const client = await getOrProvisionOidcClient(db, { clientId: body.client_id, redirectUri: body.redirect_uri });
    if (!client) return reply.code(400).send({ error: "invalid_client" });
    if (!client.redirectUris.includes(body.redirect_uri))
      return reply.code(400).send({ error: "invalid_request", error_description: "redirect_uri_not_allowed" });

    const codeRes = await db.query(
      "select tenant_id, user_id, scope, world, code_challenge, code_challenge_method, expires_at from hos_oidc_auth_codes where code = $1",
      [body.code]
    );
    if (codeRes.rowCount === 0) return reply.code(400).send({ error: "invalid_grant" });
    const row = codeRes.rows[0];

    const exp = new Date(String(row.expires_at));
    if (Number.isFinite(exp.getTime()) && exp.getTime() < Date.now()) {
      await db.query("delete from hos_oidc_auth_codes where code = $1", [body.code]);
      return reply.code(400).send({ error: "invalid_grant" });
    }

    if (String(row.code_challenge_method) !== "S256") return reply.code(400).send({ error: "invalid_grant" });
    const expectedChallenge = String(row.code_challenge);
    const actualChallenge = sha256Base64Url(body.code_verifier);
    if (expectedChallenge !== actualChallenge) return reply.code(400).send({ error: "invalid_grant" });

    await db.query("delete from hos_oidc_auth_codes where code = $1", [body.code]);

    const userRes = await db.query("select email, role from users where id = $1", [row.user_id]);
    if (userRes.rowCount === 0) return reply.code(400).send({ error: "invalid_grant" });
    const email = String(userRes.rows[0].email ?? "");
    const role = String(userRes.rows[0].role ?? "member");

    const issuer = publicIssuerFromReq(req);
    const now = Math.floor(Date.now() / 1000);
    const expiresIn = 60 * 15;

    const key = await ensureOidcSigningKey(db);
    const idTokenPayload = {
      iss: issuer,
      aud: body.client_id,
      sub: String(row.user_id),
      iat: now,
      exp: now + expiresIn,
      email,
      name: email || "user",
      hos_user_id: String(row.user_id),
      tenant_id: String(row.tenant_id),
      world: String(row.world)
    };
    const id_token = jwt.sign(idTokenPayload, key.privatePem, { algorithm: "RS256", keyid: key.kid });

    const access_token = signAccessToken({
      sub: String(row.user_id),
      tenantId: String(row.tenant_id),
      role
    });

    return reply.send({
      token_type: "Bearer",
      expires_in: expiresIn,
      access_token,
      id_token,
      scope: String(row.scope ?? "openid profile email")
    });
  });

  app.get("/userinfo", async (req, reply) => {
    const devVerbose =
      String(process.env.HOS_DEBUG_OIDC ?? "").toLowerCase() === "true" ||
      String(process.env.NODE_ENV ?? "").toLowerCase() !== "production";
    const deny = (desc) =>
      reply
        .code(401)
        .send(devVerbose ? { error: "invalid_token", error_description: String(desc) } : { error: "invalid_token" });

    const authz = String(req.headers.authorization ?? "");
    const m = authz.match(/^Bearer\s+(.+)$/i);
    if (!m) return deny("missing_bearer");
    let payload;
    try {
      payload = verifyAccessToken(m[1]);
    } catch {
      return deny("verify_failed");
    }
    const sub = String(payload?.sub ?? "");
    const tenantId = String(payload?.tenantId ?? payload?.tenant_id ?? "");
    if (!sub || !tenantId) return deny("missing_claims");

    const userRes = await db.query("select email, role from users where id = $1 and tenant_id = $2", [sub, tenantId]);
    if (userRes.rowCount === 0) return deny("user_not_found");
    const email = String(userRes.rows[0].email ?? "");
    const role = String(userRes.rows[0].role ?? "member");

    return reply.send({
      sub,
      hos_user_id: sub,
      email,
      name: email || "user",
      tenant_id: tenantId,
      role
    });
  });
}
