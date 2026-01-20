/**
 * Minimal resolver for allowed-actions endpoint.
 *
 * Canonical output:
 * { actions: string[] }
 */
export function resolveAllowedActions({ actor, subject, contract }) {
  const role = String(actor?.role ?? "");
  const type = String(subject?.type ?? "").toLowerCase();
  const status = String(subject?.status ?? "").toLowerCase();

  // Conservative default: no actions.
  if (!type || !status) return { actions: [] };

  // Owner: use contract's allowed actions as-is for now.
  if (role === "tenant_owner" || role === "super_admin") {
    const allowed = Array.isArray(contract?.allowed) ? contract.allowed.map(String) : [];
    return { actions: allowed };
  }

  // Staff: MVP = no actions unless explicitly granted (extend later).
  return { actions: [] };
}



