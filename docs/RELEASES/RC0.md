# RC0 Release Definition

**Status:** Release Candidate 0

**Date:** 2026-01-10

## RC0 Tanımı

RC0 (Release Candidate 0) is the pre-production readiness gate that validates all infrastructure, operations, and security requirements before product development begins.

RC0 ensures:
- Stack health and stability
- Architecture conformance
- Security posture
- Operational readiness
- No blocking UI errors (500 errors eliminated)

## RC0 PASS Kriterleri

RC0 PASS requires ALL of the following checks to PASS (no blocking failures):

### 1. Repository Health
- **Check:** `ops/doctor.ps1`
- **Status:** Must be PASS
- **Validates:** Git status, tracked secrets, forbidden artifacts, health endpoints

### 2. Stack Verification
- **Check:** `ops/verify.ps1 -Release` (RC0 mode)
- **Status:** Must be PASS
- **Validates:**
  - Docker Compose services running
  - H-OS health endpoint (`/v1/health`) accessible
  - Pazar health endpoint (`/up`) accessible (required in RC0 mode)
  - **Pazar FS posture** (storage/logs writability) - NEW in RC0

### 3. Architecture Conformance
- **Check:** `ops/conformance.ps1`
- **Status:** Must be PASS
- **Validates:**
  - World registry drift (WORLD_REGISTRY.md matches config/worlds.php)
  - Forbidden artifacts (no *.bak, *.tmp, *.orig, *.swp, *~)
  - Disabled-world code policy (no controller code for disabled worlds)
  - Canonical docs presence
  - Secrets safety (no tracked secrets)

### 4. Environment Contract
- **Check:** `ops/env_contract.ps1`
- **Status:** Must be PASS
- **Validates:** Required environment variables, production guardrails (CORS, session security)

### 5. Security Audit
- **Check:** `ops/security_audit.ps1`
- **Status:** Must be PASS
- **Validates:** Route/middleware security audit, admin/panel surface protection

### 6. Auth Security Check
- **Check:** `ops/auth_security_check.ps1`
- **Status:** Must be PASS
- **Validates:** Unauthorized access protection, rate limiting, security headers

### 7. Tenant Boundary Check
- **Check:** `ops/tenant_boundary_check.ps1`
- **Status:** PASS or WARN
- **Validates:** Tenant isolation, cross-tenant access prevention
- **Note:** WARN if secrets not configured (required for production, optional for RC0)

### 8. Session Posture Check
- **Check:** `ops/session_posture_check.ps1`
- **Status:** PASS or WARN
- **Validates:** Session cookie security flags (Secure, HttpOnly, SameSite), auth endpoint security
- **Note:** FAIL in local/dev is mapped to WARN (non-blocking for RC0)

### 9. SLO Check
- **Check:** `ops/slo_check.ps1 -N 10`
- **Status:** PASS or WARN
- **Validates:** Availability, p50/p95 latency, error rate
- **Note:** FAIL is mapped to WARN (non-blocking for RC0, p50 is informational)

### 10. Observability Status
- **Check:** `ops/alert_pipeline_proof.ps1` or manual Prometheus/Alertmanager check
- **Status:** PASS or WARN
- **Validates:** Alertmanager -> Webhook pipeline, Prometheus/Alertmanager ready
- **Note:** WARN only if observability not available (optional for RC0)

### 11. Routes Snapshot
- **Check:** `ops/routes_snapshot.ps1`
- **Status:** PASS or WARN
- **Validates:** API route signature comparison (contract validation)
- **Note:** Real FAIL stays FAIL (not auto-mapped to WARN)

### 12. Schema Snapshot
- **Check:** `ops/schema_snapshot.ps1`
- **Status:** Must be PASS
- **Validates:** Database schema contract (no unexpected schema changes)

### 13. Error Contract Check
- **Check:** `ops/error_contract_check.ps1` or inline check
- **Status:** Must be PASS
- **Validates:** Standard error envelope format (422 VALIDATION_ERROR, 404 NOT_FOUND with request_id)

### 14. World Spine Check
- **Check:** `ops/world_spine_check.ps1`
- **Status:** Must be PASS
- **Validates:** Enabled worlds have route/controller surfaces and ctx.world lock evidence, disabled worlds have no controller code

## RC0 Release Checklist

Before declaring RC0 PASS, verify:

- [ ] `ops/release_check.ps1` PASS or WARN (git status clean, RC0 gate PASS, required docs present, snapshots present, VERSION valid)
- [ ] `ops/ops_status.ps1` unified dashboard shows all critical checks PASS
- [ ] `ops/verify.ps1 -Release` PASS (includes Pazar FS posture check)
- [ ] `ops/conformance.ps1` PASS (world registry drift fixed)
- [ ] `ops/env_contract.ps1` PASS
- [ ] `ops/session_posture_check.ps1` PASS or WARN (local/dev OK)
- [ ] `ops/auth_security_check.ps1` PASS
- [ ] `ops/tenant_boundary_check.ps1` PASS or WARN (secrets OK)
- [ ] `ops/world_spine_check.ps1` PASS
- [ ] **UI 500 errors eliminated** (Pazar storage/logs writable, laravel.log permission fixed)
- [ ] Observability status WARN acceptable (optional for RC0)

## Ürün Geliştirmeye Geçiş Koşulu

**RC0 PASS + UI 500 yok**

Before starting product development:
1. RC0 gate must PASS (all blocking checks PASS, WARN acceptable for non-blocking)
2. UI must not show 500 errors (storage/logs writable, no permission denied)
3. All ops gates operational (verify, conformance, security, etc.)
4. Request tracing functional (request_id in logs, request_trace.ps1 working)

## RC0 Completion Criteria

RC0 is complete when:
- All RC0 PASS kriterleri met
- UI 500 errors eliminated
- All proof documents created (`docs/PROOFS/rc0_*.md`)
- RC0 release documentation complete (`docs/RELEASES/RC0.md`)
- Product roadmap defined (`docs/PRODUCT/PRODUCT_ROADMAP.md`)
- MVP scope defined (`docs/PRODUCT/MVP_SCOPE.md`)

## Post-RC0: Product Development

Once RC0 PASS is achieved:
- Start MVP development (World 1: commerce vertical slice)
- Follow product roadmap (MVP-0 → MVP-1 → MVP-2)
- Maintain ops gates (verify, conformance, security, etc.)
- Continue monitoring (UI errors, storage posture, request traces)

## Related Documents

- `docs/PROOFS/rc0_pazar_storage_permissions_pass.md` - Storage permissions fix proof
- `docs/PROOFS/rc0_truthful_gate_pass.md` - RC0 gate truthful policy proof
- `docs/PROOFS/world_registry_drift_fix.md` - World registry alignment proof
- `docs/PROOFS/db_contract_pass.md` - Schema snapshot drift fix proof
- `docs/PRODUCT/PRODUCT_ROADMAP.md` - Product development roadmap
- `docs/PRODUCT/MVP_SCOPE.md` - MVP scope for World 1 (commerce)
- `docs/RULES.md` - Rule 37: RC0 gate must PASS/WARN before RC0 tag
- `docs/RULES.md` - Rule 39: RC0 gate truthful policy






