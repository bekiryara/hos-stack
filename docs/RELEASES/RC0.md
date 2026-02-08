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
- **Check:** `.\ops\ops.ps1 doctor`
- **Status:** Must be PASS
- **Validates:** Git status, tracked secrets, forbidden artifacts, health endpoints

### 2. Stack Verification
- **Check:** `.\ops\ops.ps1 verify -Release` (RC0 mode)
- **Status:** Must be PASS
- **Validates:**
  - Docker Compose services running
  - H-OS health endpoint (`/v1/health`) accessible
  - Pazar health endpoint (`/up`) accessible (required in RC0 mode)
  - **Pazar FS posture** (storage/logs writability) - NEW in RC0

### 3. Architecture Conformance
- **Check:** `.\ops\ops.ps1 conformance`
- **Status:** Must be PASS
- **Validates:**
  - World registry drift (WORLD_REGISTRY.md matches config/worlds.php)
  - Forbidden artifacts (no *.bak, *.tmp, *.orig, *.swp, *~)
  - Disabled-world code policy (no controller code for disabled worlds)
  - Canonical docs presence
  - Secrets safety (no tracked secrets)

### 4. Environment Contract
- **Check:** `.\ops\ops.ps1 env-contract`
- **Status:** Must be PASS
- **Validates:** Required environment variables, production guardrails (CORS, session security)

### 5. Security Audit
- **Check:** `.\ops\ops.ps1 security-audit`
- **Status:** Must be PASS
- **Validates:** Route/middleware security audit, admin/panel surface protection

### 6. Auth Security Check
- **Check:** `.\ops\ops.ps1 auth-security`
- **Status:** Must be PASS
- **Validates:** Unauthorized access protection, rate limiting, security headers

### 7. Tenant Boundary Check
- **Check:** `.\ops\ops.ps1 tenant-boundary`
- **Status:** PASS or WARN
- **Validates:** Tenant isolation, cross-tenant access prevention
- **Note:** WARN if secrets not configured (required for production, optional for RC0)

### 8. Session Posture Check
- **Check:** `.\ops\ops.ps1 session-posture`
- **Status:** PASS or WARN
- **Validates:** Session cookie security flags (Secure, HttpOnly, SameSite), auth endpoint security
- **Note:** FAIL in local/dev is mapped to WARN (non-blocking for RC0)

### 9. SLO Check
- **Check:** `.\ops\ops.ps1 slo-check -N 10`
- **Status:** PASS or WARN
- **Validates:** Availability, p50/p95 latency, error rate
- **Note:** FAIL is mapped to WARN (non-blocking for RC0, p50 is informational)

### 10. Observability Status
- **Check:** `.\ops\ops.ps1 observability-status` (or manual Prometheus/Alertmanager check)
- **Status:** PASS or WARN
- **Validates:** Alertmanager -> Webhook pipeline, Prometheus/Alertmanager ready
- **Note:** WARN only if observability not available (optional for RC0)

### 11. Routes Snapshot
- **Check:** `.\ops\ops.ps1 routes-snapshot`
- **Status:** PASS or WARN
- **Validates:** API route signature comparison (contract validation)
- **Note:** Real FAIL stays FAIL (not auto-mapped to WARN)

### 12. Schema Snapshot
- **Check:** `.\ops\ops.ps1 schema-snapshot`
- **Status:** Must be PASS
- **Validates:** Database schema contract (no unexpected schema changes)

### 13. Error Contract Check
- **Check:** `.\ops\ops.ps1 error-contract`
- **Status:** Must be PASS
- **Validates:** Standard error envelope format (422 VALIDATION_ERROR, 404 NOT_FOUND with request_id)

### 14. World Spine Check
- **Check:** `.\ops\ops.ps1 world-spine`
- **Status:** Must be PASS
- **Validates:** Enabled worlds have route/controller surfaces and ctx.world lock evidence, disabled worlds have no controller code

## RC0 Release Checklist

Before declaring RC0 PASS, verify:

- [ ] `ops/ops.ps1 release-check` PASS or WARN (git status clean, RC0 gate PASS/WARN, required docs present, snapshots present, VERSION valid)
- [ ] `ops/ops_status.ps1` unified dashboard shows all critical checks PASS
- [ ] `.\ops\ops.ps1 verify -Release` PASS (includes Pazar FS posture check)
- [ ] `.\ops\ops.ps1 conformance` PASS (world registry drift fixed)
- [ ] `.\ops\ops.ps1 env-contract` PASS
- [ ] `.\ops\ops.ps1 session-posture` PASS or WARN (local/dev OK)
- [ ] `.\ops\ops.ps1 auth-security` PASS
- [ ] `.\ops\ops.ps1 tenant-boundary` PASS or WARN (secrets OK)
- [ ] `.\ops\ops.ps1 world-spine` PASS
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
- RC0 icin kanit notlari `docs/PROOFS/PASS_LOG.md` icine eklendi
- RC0 release documentation complete (`docs/RELEASES/RC0.md`)
- Product API spine documented (`docs/PRODUCT/PRODUCT_API_SPINE.md`)

## Post-RC0: Product Development

Once RC0 PASS is achieved:
- Start MVP development (marketplace world vertical slice)
- Follow product roadmap (MVP-0 → MVP-1 → MVP-2)
- Maintain ops gates (verify, conformance, security, etc.)
- Continue monitoring (UI errors, storage posture, request traces)

## Related Documents

- `docs/PROOFS/PASS_LOG.md` - RC0 ve WP kanit notlari (tek dosya)
- `docs/CURRENT.md` - Current baseline / stack truth
- `docs/PRODUCT/PRODUCT_API_SPINE.md` - Product API spine
- `docs/RULES.md` - Rule 37: RC0 gate must PASS/WARN before RC0 tag
- `docs/RULES.md` - Rule 39: RC0 gate truthful policy






