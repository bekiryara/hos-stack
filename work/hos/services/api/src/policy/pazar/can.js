/**
 * Minimal Pazar policy engine (MVP).
 *
 * This repo originally had richer matrices; some files were empty placeholders.
 * For Register alignment we keep behavior intentionally conservative.
 */
export function canPazar({ role, ability, actorId }) {
  const r = String(role ?? "").trim();
  const a = String(ability ?? "").trim();
  const actor = String(actorId ?? "").trim();

  if (!a) return { allowed: false, reason: "missing_ability" };

  // Public abilities: allow if caller is authenticated (actor_id present).
  if (a.startsWith("public.") && actor) {
    return { allowed: true, reason: "allowed_public_authenticated" };
  }

  // Super admin / owner: allow (MVP).
  if (r === "super_admin" || r === "tenant_owner") return { allowed: true, reason: "allowed" };

  // Staff: default deny, allow only explicitly whitelisted abilities.
  if (r === "tenant_staff") {
    const allow = new Set([
      // keep very small in MVP; extend via role matrix later
    ]);
    if (allow.has(a)) return { allowed: true, reason: "allowed" };
    return { allowed: false, reason: "forbidden" };
  }

  return { allowed: false, reason: "forbidden" };
}







