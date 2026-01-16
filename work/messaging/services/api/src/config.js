import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  MESSAGING_API_KEY: z.string().min(1).default("dev-messaging-key"),
  NODE_ENV: z.enum(["development", "test", "production"]).optional()
});

export function getConfig() {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    const msg = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ");
    throw new Error(`Invalid configuration: ${msg}`);
  }
  return parsed.data;
}

