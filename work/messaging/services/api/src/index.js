import { getConfig } from "./config.js";
import { applyMigrations, makeDb } from "./db.js";
import { buildApp } from "./app.js";

const cfg = getConfig();

const db = makeDb(cfg.DATABASE_URL);

// Ensure schema is present on boot (idempotent)
await applyMigrations(db);

const app = await buildApp({ db });

await app.listen({ port: cfg.PORT, host: "0.0.0.0" });

async function shutdown() {
  try {
    await app.close();
  } catch {
    // ignore
  }
  try {
    await db.end();
  } catch {
    // ignore
  }
  process.exit(0);
}

process.once("SIGTERM", shutdown);
process.once("SIGINT", shutdown);

