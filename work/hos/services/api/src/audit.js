import crypto from "node:crypto";

/**
 * Append-only audit writer (MVP).
 *
 * Schema: migrations/001_init.sql -> audit_events(id, tenant_id, actor_user_id, action, metadata)
 *
 * IMPORTANT:
 * - Audit must never block core flows in MVP; failures should be non-fatal.
 */
export async function audit(db, { action, tenantId = null, actorUserId = null, metadata = {} }) {
  try {
    const id = crypto.randomUUID();
    const tenant_id = tenantId ? String(tenantId) : null;
    const actor_user_id = actorUserId ? String(actorUserId) : null;
    const payload = metadata && typeof metadata === "object" ? metadata : { value: metadata };
    if (!action) return { ok: false, error: "missing_action" };

    if (db && typeof db.query === "function") {
      await db.query(
        "insert into audit_events (id, tenant_id, actor_user_id, action, metadata) values ($1,$2,$3,$4,$5::jsonb)",
        [id, tenant_id, actor_user_id, String(action), JSON.stringify(payload)]
      );
    }

    return { ok: true, id };
  } catch (e) {
    // Non-fatal in MVP
    return { ok: false, error: "audit_failed" };
  }
}







