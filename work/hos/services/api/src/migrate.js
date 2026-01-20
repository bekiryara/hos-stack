import { makeDb, applyMigrations } from "./db.js";

// Standalone migration entrypoint.
// Intentionally does NOT require JWT_SECRET; only needs DATABASE_URL.
const databaseUrl = process.env.DATABASE_URL;
const db = makeDb(databaseUrl);

try {
  await applyMigrations(db);
} finally {
  // Pool#end exists on pg Pool.
  await db.end();
}




