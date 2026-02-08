import test from "node:test";
import assert from "node:assert/strict";

import { buildApp } from "../src/app.js";

test("remote H-OS: GET /v1/health returns canonical shape", async () => {
  const app = await buildApp({ db: { query: async () => ({ rowCount: 1, rows: [{ ok: true }] }) } });
  const res = await app.inject({ method: "GET", url: "/v1/health" });
  assert.equal(res.statusCode, 200);
  const json = res.json();
  assert.equal(json.ok, true);
  await app.close();
});

test("remote H-OS: POST /v1/contract/can-transition returns allowed=true for valid transition", async () => {
  const app = await buildApp({ db: { query: async () => ({ rowCount: 1, rows: [{ ok: true }] }) } });

  const res = await app.inject({
    method: "POST",
    url: "/v1/contract/can-transition",
    payload: {
      subject_ref: { type: "reservation", status: "pending", tenant_id: "t1", world_id: "marketplace" },
      to: "confirmed",
      ctx: { world: "marketplace" }
    }
  });
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.json(), { allowed: true, reason: "allowed" });

  await app.close();
});


