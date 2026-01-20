/**
 * Minimal reservation contract -> allowed actions mapping.
 *
 * Returns:
 * { allowed: string[], denied: Record<string,string> }
 */
export function reservationAllowedActionsByStatus({ status }) {
  const s = String(status ?? "").toLowerCase();

  if (s === "requested") {
    return { allowed: ["reservation.cancel", "reservation.confirm"], denied: {} };
  }

  if (s === "pending") {
    return { allowed: ["reservation.cancel"], denied: {} };
  }

  return { allowed: [], denied: {} };
}



