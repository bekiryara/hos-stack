/**
 * World allowlist + closed-world enforcement (REGISTER v1.2 / FOUNDING_SPEC).
 *
 * Shared helper to prevent drift across route files.
 * No behavior change — extracted from core_world_contract.js and admin_permits.js.
 */
export function createWorldEnforcer() {
  const CANONICAL_WORLDS = ["marketplace", "messaging", "social"];

  const allowedWorlds = new Set(
    String(process.env.HOS_WORLD_ALLOWLIST ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
  );
  if (allowedWorlds.size === 0) {
    for (const w of CANONICAL_WORLDS) allowedWorlds.add(w);
  }

  const closedWorlds = new Set(
    String(process.env.HOS_WORLD_CLOSED ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
  );

  function enforceWorldOrReply(reply, worldRaw) {
    const world = String(worldRaw ?? "").trim();
    if (!world) {
      reply.code(400).send({ error: "missing_world" });
      return null;
    }
    if (!allowedWorlds.has(world)) {
      reply.code(400).send({ error: "invalid_world" });
      return null;
    }
    if (closedWorlds.has(world)) {
      reply.code(410).send({ error: "world_closed", error_subcode: "WORLD_CLOSED" });
      return null;
    }
    return world;
  }

  return { enforceWorldOrReply };
}

