import pg from "pg";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const { Pool } = pg;

export function makeDb(databaseUrl) {
  const url = String(databaseUrl || "").trim();
  if (!url) throw new Error("DATABASE_URL is required");
  
  return new Pool({ connectionString: url });
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function defaultMigrationsDir() {
  return path.join(__dirname, "..", "migrations");
}

export async function applyMigrations(db, { migrationsDir = defaultMigrationsDir() } = {}) {
  await db.query(`
    create table if not exists schema_migrations (
      id text primary key,
      applied_at timestamptz not null default now()
    );
  `);

  const entries = await fs.readdir(migrationsDir, { withFileTypes: true });
  const files = entries
    .filter((e) => e.isFile() && e.name.endsWith(".sql"))
    .map((e) => e.name)
    .sort();

  const appliedRes = await db.query("select id from schema_migrations");
  const applied = new Set(appliedRes.rows.map((r) => r.id));

  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = await fs.readFile(path.join(migrationsDir, file), "utf8");
    const client = await db.connect();
    try {
      await client.query("begin");
      await client.query(sql);
      await client.query("insert into schema_migrations (id) values ($1)", [file]);
      await client.query("commit");
    } catch (e) {
      try {
        await client.query("rollback");
      } catch {
        // ignore rollback errors
      }
      throw e;
    } finally {
      client.release();
    }
  }
}



