import test from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.js";

test("x-request-id is echoed back when provided", async () => {
  const db = { query: async () => ({ rowCount: 1, rows: [] }) };
  const app = await buildApp({ db });

  const res = await app.inject({
    method: "GET",
    url: "/health",
    headers: { "x-request-id": "req-test-12345678" }
  });

  assert.equal(res.statusCode, 200);
  assert.equal(res.headers["x-request-id"], "req-test-12345678");

  await app.close();
});

test("x-request-id is generated when missing", async () => {
  const db = { query: async () => ({ rowCount: 1, rows: [] }) };
  const app = await buildApp({ db });

  const res = await app.inject({ method: "GET", url: "/health" });
  assert.equal(res.statusCode, 200);
  assert.ok(typeof res.headers["x-request-id"] === "string");
  assert.ok(res.headers["x-request-id"].length >= 8);

  await app.close();
});




