import test from "node:test";
import assert from "node:assert/strict";
import { PassThrough } from "node:stream";
import { buildApp } from "../src/app.js";

test("logs redact authorization + cookie headers", async () => {
  const db = { query: async () => ({ rowCount: 1, rows: [] }) };

  const stream = new PassThrough();
  let out = "";
  stream.on("data", (c) => (out += c.toString("utf8")));

  const app = await buildApp({ db, logStream: stream });

  const secretAuth = "Bearer super-secret-token";
  const secretCookie = "hos_refresh=super-secret-cookie";

  // Fastify's default request logs do not include headers (good).
  // We explicitly log an object containing those fields to validate redaction config.
  app.log.info(
    {
      headers: {
        authorization: secretAuth,
        cookie: secretCookie
      }
    },
    "redaction test"
  );

  // give the logger a tick to flush
  await new Promise((r) => setTimeout(r, 10));
  await app.close();

  // pino writes NDJSON
  const lines = out
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean)
    .filter((s) => s.startsWith("{") && s.endsWith("}"));

  // At least one request log line should be emitted.
  assert.ok(lines.length >= 1);

  // Secrets must never appear in logs.
  assert.ok(!out.includes("super-secret-token"));
  assert.ok(!out.includes("super-secret-cookie"));

  // We expect redaction marker to appear.
  assert.ok(out.includes("[REDACTED]"));

  // Stronger check: find our log line with headers and verify it is redacted.
  const parsed = lines.map((l) => JSON.parse(l));
  const withHeaders = parsed.find((o) => o && o.msg === "redaction test" && o.headers);
  assert.ok(withHeaders);
  assert.equal(withHeaders.headers.authorization, "[REDACTED]");
  assert.equal(withHeaders.headers.cookie, "[REDACTED]");
});


