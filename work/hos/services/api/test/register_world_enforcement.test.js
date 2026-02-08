import test from "node:test";
import assert from "node:assert/strict";

import { buildApp } from "../src/app.js";

test("REGISTER v1.2: missing ctx.world is rejected (400) on /v1/contract/can-transition", async () => {
  const app = await buildApp({ db: { query: async () => ({ rowCount: 1, rows: [{ ok: true }] }) } });
  const res = await app.inject({
    method: "POST",
    url: "/v1/contract/can-transition",
    payload: {
      subject_ref: { type: "reservation", status: "pending", tenant_id: "t1" },
      to: "confirmed",
      ctx: { tenant_id: "t1" }
    }
  });

  assert.equal(res.statusCode, 400);
  assert.equal(res.json()?.error, "missing_world");

  await app.close();
});

test("REGISTER v1.2: closed world is rejected (410 WORLD_CLOSED) on /v1/contract/transition", async () => {
  const prevKey = process.env.HOS_API_KEY;
  const prevClosed = process.env.HOS_WORLD_CLOSED;
  process.env.HOS_API_KEY = "test-api-key";
  process.env.HOS_WORLD_CLOSED = "social";

  const app = await buildApp({ db: { query: async () => ({ rowCount: 1, rows: [{ ok: true }] }) } });
  const res = await app.inject({
    method: "POST",
    url: "/v1/contract/transition",
    headers: { "x-hos-api-key": "test-api-key" },
    payload: {
      subject_ref: { type: "reservation", id: "r1", tenant_id: "t1" },
      to: "cancelled",
      meta: {},
      attrs: {},
      idempotency_key: "pazar:test:idem:1",
      ctx: { tenant_id: "t1", world: "social", from: "requested" }
    }
  });

  assert.equal(res.statusCode, 410);
  assert.equal(res.json()?.error_subcode, "WORLD_CLOSED");

  await app.close();
  process.env.HOS_API_KEY = prevKey;
  process.env.HOS_WORLD_CLOSED = prevClosed;
});




