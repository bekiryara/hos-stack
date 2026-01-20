/**
 * Minimal contract transition rules for Pazar (MVP).
 * Returns { allowed, reason? }.
 */
export function canTransitionPazar({ subject_ref, to }) {
  const type = String(subject_ref?.type ?? "").toLowerCase();
  const from = String(subject_ref?.status ?? "").toLowerCase();
  const target = String(to ?? "").toLowerCase();

  if (!type) return { allowed: false, reason: "missing_subject_type" };
  if (!from) return { allowed: false, reason: "missing_from_status" };
  if (!target) return { allowed: false, reason: "missing_to_status" };

  const terminalByType = {
    order: new Set(["cancelled"]),
    payment: new Set(["paid", "failed", "cancelled"]),
    reservation: new Set(["cancelled", "completed"])
  };

  const terminals = terminalByType[type];
  if (terminals && terminals.has(from)) {
    return { allowed: false, reason: "terminal_state" };
  }

  if (type === "order") {
    if (from === "pending" && (target === "paid" || target === "cancelled")) return { allowed: true, reason: "allowed" };
    if (from === "paid" && target === "cancelled") return { allowed: true, reason: "allowed" };
    return { allowed: false, reason: "invalid_transition" };
  }

  if (type === "payment") {
    if (from === "pending" && (target === "paid" || target === "failed" || target === "cancelled")) return { allowed: true, reason: "allowed" };
    return { allowed: false, reason: "invalid_transition" };
  }

  if (type === "reservation") {
    // Mirrors Pazar ReservationContract
    if (from === "pending" && (target === "confirmed" || target === "cancelled")) return { allowed: true, reason: "allowed" };
    if (from === "confirmed" && (target === "checked_in" || target === "cancelled")) return { allowed: true, reason: "allowed" };
    if (from === "checked_in" && (target === "completed" || target === "cancelled")) return { allowed: true, reason: "allowed" };
    return { allowed: false, reason: "invalid_transition" };
  }

  return { allowed: false, reason: "unknown_subject_type" };
}








