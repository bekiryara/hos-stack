import test from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.js";

test("GET /v1/meta/features returns feature flags", async () => {
  const db = { query: async () => ({ rowCount: 1, rows: [] }) };
  const app = await buildApp({ db });

  const res = await app.inject({ method: "GET", url: "/v1/meta/features" });
  assert.equal(res.statusCode, 200);
  const body = res.json();
  assert.equal(typeof body.googleOAuthConfigured, "boolean");
  assert.equal(typeof body.otelEnabled, "boolean");

  await app.close();
});



