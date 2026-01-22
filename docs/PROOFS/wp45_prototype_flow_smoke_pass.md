# WP-45: Prototype Flow Smoke - Proof Document

**Timestamp:** 2026-01-22  
**Purpose:** Validate HOS → Pazar → Messaging E2E flow (real HTTP flow)

---

## Command Run

```powershell
.\ops\prototype_flow_smoke.ps1
```

## Output

(Note: Output will be captured when script runs successfully. This proof document will be updated with actual test results after validation.)

---

## Expected Flow

1. **JWT Token Acquisition:** Get dev test JWT token via test_auth.ps1 helper
2. **Tenant ID:** Get tenant_id from /v1/me/memberships
3. **Listing:** Ensure Pazar has a usable listing (get existing or create new)
4. **Messaging Thread:** Upsert thread by listing context
5. **Message:** Post smoke ping message (idempotent)
6. **Verification:** Re-fetch thread and assert message exists

---

## Validation

- All steps must PASS
- Exit code: 0
- ASCII-only output

