import test from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.js";

test("GET /v1/auth/google/start returns 501 when Google OAuth not configured", async () => {
  delete process.env.GOOGLE_CLIENT_ID;
  delete process.env.GOOGLE_CLIENT_SECRET;
  delete process.env.GOOGLE_REDIRECT_URI;

  const db = { query: async () => ({ rowCount: 0, rows: [] }) };
  const app = await buildApp({ db });

  const res = await app.inject({ method: "GET", url: "/v1/auth/google/start?tenantSlug=demo" });
  assert.equal(res.statusCode, 501);
  assert.equal(res.json().error, "google_oauth_not_configured");

  await app.close();
});



