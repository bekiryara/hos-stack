import test from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.js";

test("GET /metrics returns Prometheus text", async () => {
  const db = { query: async () => ({ rowCount: 1, rows: [] }) };
  const app = await buildApp({ db });

  // Generate at least one request for request-level metrics.
  const health = await app.inject({ method: "GET", url: "/health" });
  assert.equal(health.statusCode, 200);

  const res = await app.inject({ method: "GET", url: "/metrics" });
  assert.equal(res.statusCode, 200);
  assert.match(res.headers["content-type"], /text\/plain/i);
  assert.match(res.body, /process_/);
  assert.match(res.body, /hos_http_requests_total/);
  assert.match(res.body, /hos_http_request_duration_seconds/);
  assert.match(res.body, /method="GET"/);

  await app.close();
});


