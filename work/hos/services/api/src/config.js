import { z } from "zod";
import fs from "node:fs";

export function readEnvOrFile(name) {
  const direct = process.env[name];
  if (direct && String(direct).length > 0) return String(direct);

  const filePath = process.env[`${name}_FILE`];
  if (!filePath) return undefined;
  try {
    return fs.readFileSync(filePath, "utf8").trim();
  } catch {
    return undefined;
  }
}

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  JWT_SECRET: z.string().min(32),
  NODE_ENV: z.enum(["development", "test", "production"]).optional()
});

export function getConfig() {
  const hydrated = {
    ...process.env,
    DATABASE_URL: readEnvOrFile("DATABASE_URL"),
    JWT_SECRET: readEnvOrFile("JWT_SECRET")
  };

  const parsed = envSchema.safeParse(hydrated);
  if (!parsed.success) {
    const msg = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ");
    throw new Error(`Invalid configuration: ${msg}`);
  }
  return parsed.data;
}





