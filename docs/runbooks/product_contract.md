# Product Contract Gate Runbook

## Overview

The Product Contract Gate (`ops/product_contract.ps1`) validates that the Product API spine documentation (`docs/product/PRODUCT_API_SPINE.md`) matches the actual public surface (routes snapshot). This ensures documentation stays aligned with implementation, preventing drift between docs and routes.

## What It Checks

The gate performs the following validations:

### [A1] Spine File Structure
- Verifies `docs/product/PRODUCT_API_SPINE.md` exists
- Checks for "Implemented endpoints" sections per world (commerce, food, rentals)

### [A2] Spine Endpoints → Routes Alignment
- For each endpoint marked `Status: IMPLEMENTED` in spine:
  - Validates there is a matching route in snapshot (method + path)
  - Route must be under `/api/v1/<world>/...` pattern
  - FAIL if IMPLEMENTED endpoint missing in snapshot

### [A3] Routes → Spine Documentation
- For each route in snapshot under `/api/v1/<world>/listings*`:
  - Validates route is documented in spine
  - FAIL if undocumented public endpoint found

### [A4] Middleware Posture
- Validates middleware from snapshot (action/middleware fields):
  - Required: `auth.any` + `resolve.tenant` + `tenant.user` for protected surfaces
  - WARN if middleware info is missing in snapshot
  - FAIL if middleware info present but required guards missing

### [A5] Error-Contract Posture Smoke
- Validates endpoints in spine declare error envelope format section
- If docker available, performs live checks:
  - Unauthorized returns 401/403 with `ok:false` + `request_id`
  - Not found returns 404 NOT_FOUND with `ok:false` + `request_id`

## Running Locally

### Basic Usage

```powershell
.\ops\product_contract.ps1
```

### With Custom Paths

```powershell
.\ops\product_contract.ps1 -SpinePath "docs\product\PRODUCT_API_SPINE.md" -RoutesSnapshotPath "ops\snapshots\routes.pazar.json"
```

### Prerequisites

- Routes snapshot: `ops/snapshots/routes.pazar.json` (preferred)
- Fallback: Routes file `work/pazar/routes/api.php` (if snapshot missing)
- Spine documentation: `docs/product/PRODUCT_API_SPINE.md`

## Interpreting Results

### Status Values

- **PASS**: All checks passed (spine and routes aligned)
- **WARN**: Warnings present (e.g., middleware info missing in snapshot)
- **FAIL**: Failures detected (e.g., undocumented endpoints, missing routes, missing middleware)

### Exit Codes

- `0`: PASS (all checks passed)
- `2`: WARN (warnings present, no failures)
- `1`: FAIL (one or more failures)

### Output Format

```
=== Check Results ===
Check | Status | Notes
--------------------------------------------------------------------------------
Spine File                    [PASS] File exists
Spine Endpoints               [PASS] Extracted 15 endpoints
Routes Snapshot               [PASS] Loaded 120 routes
Spine-Routes Alignment         [PASS] All endpoints present
Routes Documentation          [PASS] All routes documented
Middleware Posture             [PASS] All routes have required middleware
Error Contract                [PASS] Error envelope format documented
```

## Troubleshooting

### FAIL: Missing Endpoints in Routes

**Symptom:** `Spine-Routes Alignment: FAIL - X endpoints missing`

**Cause:** Endpoint marked IMPLEMENTED in spine but route not found in snapshot

**Fix:**
1. Check if route exists in `work/pazar/routes/api.php`
2. Run `ops/routes_snapshot.ps1` to update snapshot
3. Verify route method and path match spine exactly

### FAIL: Undocumented Routes

**Symptom:** `Routes Documentation: FAIL - X undocumented routes`

**Cause:** Route exists in snapshot but not documented in spine

**Fix:**
1. Add endpoint documentation to `docs/product/PRODUCT_API_SPINE.md`
2. Mark endpoint as `Status: IMPLEMENTED`
3. Include method, path, auth requirements, response format

### FAIL: Missing Middleware

**Symptom:** `Middleware Posture: FAIL - X routes missing required middleware`

**Cause:** Route missing required middleware (`auth.any`, `resolve.tenant`, `tenant.user`)

**Fix:**
1. Check route definition in `work/pazar/routes/api.php`
2. Add missing middleware to route group or individual route
3. Re-run `ops/routes_snapshot.ps1` to update snapshot

### WARN: Middleware Info Missing

**Symptom:** `Middleware Posture: WARN - Middleware info missing for X routes`

**Cause:** Routes snapshot doesn't include middleware information

**Fix:**
1. Check if `php artisan route:list --json` includes middleware field
2. Update Laravel version if needed (middleware field may be missing in older versions)
3. Gate will WARN but not FAIL (non-blocking)

## CI Integration

The gate is integrated into CI via `.github/workflows/product-contract.yml`:

- Runs on push/PR to `main`/`develop`
- Triggers on changes to:
  - `work/pazar/routes/api.php`
  - `docs/product/PRODUCT_API_SPINE.md`
  - `ops/product_contract.ps1`
- No docker required for baseline checks (docker optional if available)
- Uploads logs on failure

## Best Practices

1. **Update Spine First**: When adding new endpoints, update spine documentation first, then implement route
2. **Keep Snapshot Current**: Run `ops/routes_snapshot.ps1` after route changes
3. **Document All Public Endpoints**: Every route under `/api/v1/<world>/listings*` must be in spine
4. **Mark Implementation Status**: Use `Status: IMPLEMENTED` for active endpoints, `Status: NOT_IMPLEMENTED` for stubs
5. **Review WARNs**: Even though WARNs don't block, review and fix middleware info gaps

## Related Documentation

- `docs/product/PRODUCT_API_SPINE.md` - Product API spine documentation
- `ops/routes_snapshot.ps1` - Routes snapshot generator
- `ops/product_contract_check.ps1` - E2E product contract validation
- `docs/RULES.md` - Rule 63: Product-contract gate (spine validation) PASS required
