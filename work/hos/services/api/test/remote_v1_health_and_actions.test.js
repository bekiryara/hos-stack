import test from "node:test";
import assert from "node:assert/strict";

import { buildApp } from "../src/app.js";

test("remote H-OS: GET /v1/health returns canonical shape", async () => {
  const app = await buildApp({ db: { query: async () => ({ rowCount: 1, rows: [{ ok: true }] }) } });
  const res = await app.inject({ method: "GET", url: "/v1/health" });
  assert.equal(res.statusCode, 200);
  const json = res.json();
  assert.equal(json.ok, true);
  assert.equal(json.service, "hos");
  assert.ok(typeof json.version === "string" && json.version.length > 0);
  await app.close();
});

test("remote H-OS: POST /v1/allowed-actions returns canonical actions[] (owner sees cancel/confirm, staff sees ops only)", async () => {
  const prevKey = process.env.HOS_API_KEY;
  process.env.HOS_API_KEY = "test-api-key";

  const app = await buildApp({ db: { query: async () => ({ rowCount: 1, rows: [{ ok: true }] }) } });

  const owner = await app.inject({
    method: "POST",
    url: "/v1/allowed-actions",
    headers: { "x-hos-api-key": "test-api-key" },
    payload: {
      actor_id: "u1",
      subject_ref: { type: "reservation", id: "r1", tenant_id: "t1", status: "requested" },
      ctx: { tenant_id: "t1", actor_role: "tenant_owner", world: "commerce" }
    }
  });
  assert.equal(owner.statusCode, 200);
  assert.deepEqual(owner.json(), { actions: ["reservation.cancel", "reservation.confirm"] });

  const staff = await app.inject({
    method: "POST",
    url: "/v1/allowed-actions",
    headers: { "x-hos-api-key": "test-api-key" },
    payload: {
      actor_id: "u2",
      subject_ref: { type: "reservation", id: "r1", tenant_id: "t1", status: "requested" },
      ctx: { tenant_id: "t1", actor_role: "tenant_staff", world: "commerce" }
    }
  });
  assert.equal(staff.statusCode, 200);
  assert.deepEqual(staff.json(), { actions: [] });

  await app.close();
  process.env.HOS_API_KEY = prevKey;
});


