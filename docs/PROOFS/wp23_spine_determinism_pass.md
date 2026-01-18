# WP-23: Test Auth Bootstrap + Spine Check Determinism - PASS

**Timestamp:** 2026-01-18  
**Status:** ✅ COMPLETE

## Purpose

Make Marketplace verification deterministic and fail-fast. Eliminate manual PRODUCT_TEST_AUTH setup by bootstrapping a valid JWT automatically (local/dev only). Fix pazar_spine_check summary crash under StrictMode ("Duration property cannot be found").

## Deliverables

1. **ops/_lib/test_auth.ps1** - Shared helper with `Get-DevTestJwtToken` function
2. **ops/ensure_product_test_auth.ps1** - Entrypoint script for users
3. **ops/reservation_contract_check.ps1** - Updated to use bootstrap token
4. **ops/rental_contract_check.ps1** - Updated to use bootstrap token
5. **ops/order_contract_check.ps1** - Updated to use bootstrap token (removed dummy token)
6. **ops/pazar_spine_check.ps1** - Fixed Duration property error (use pscustomobject)

## Changes

### A) Shared Helper: ops/_lib/test_auth.ps1

Created `Get-DevTestJwtToken` function that:
- Takes optional parameters: `$HosBaseUrl` (default: http://localhost:3000), `$TenantSlug` (default: tenant-a), `$Email` (default: test.user+wp23@local), `$Password` (default: Passw0rd!), `$HosApiKey` (default: dev-api-key)
- Calls `POST $HosBaseUrl/v1/admin/users/upsert` with header `x-hos-api-key:$HosApiKey` to ensure user exists
- Calls `POST $HosBaseUrl/v1/auth/login` with body `{tenantSlug,email,password}` to obtain JWT
- Returns token string and sets:
  - `$script:DevJwt = $token`
  - `$env:PRODUCT_TEST_AUTH = "Bearer $token"`
  - `$env:HOS_TEST_AUTH = "Bearer $token"`
- Throws clear error with remediation text if any step fails

### B) Auth-Required Contract Checks Updated

**reservation_contract_check.ps1:**
- Removed "dummy token" fallback
- If PRODUCT_TEST_AUTH is missing/invalid, calls helper to bootstrap token
- Validates JWT format (two dots) after bootstrap; if still invalid => FAIL (exit 1)

**rental_contract_check.ps1:**
- Same pattern as reservation_contract_check.ps1

**order_contract_check.ps1:**
- Removed dummy token fallback ("Bearer test-token-genesis-wp13")
- Uses bootstrap token pattern (same as reservation/rental)

### C) pazar_spine_check.ps1 Summary Crash Fix

**Before:**
```powershell
$results += @{ Name = $check.Name; WP = $check.WP; Status = "PASS"; Duration = $duration.TotalSeconds }
# ...
$durationText = if ($result.Duration) { " ($($result.Duration.ToString('F2'))s)" } else { "" }
```

**After:**
```powershell
$results += [PSCustomObject]@{
    Name = $check.Name
    WP = $check.WP
    Status = "PASS"
    Reason = $null
    ExitCode = 0
    DurationSec = $durationSec
}
# ...
$durationSec = $result.DurationSec
$durationText = if ($durationSec -ne $null) { " ($($durationSec.ToString('F2'))s)" } else { "" }
```

**Changes:**
- Convert $results entries to [PSCustomObject] with fixed properties: Name, WP, Status, Reason, ExitCode, DurationSec
- Always include DurationSec (set to $null if unknown) to avoid property-missing errors
- In summary printing, use safe property access (check for $null)

### D) Entrypoint: ops/ensure_product_test_auth.ps1

Created user-friendly entrypoint that:
- Dot-sources `ops/_lib/test_auth.ps1`
- Calls `Get-DevTestJwtToken`
- Prints "OK: PRODUCT_TEST_AUTH set for this process"
- Prints ONLY redacted token preview (first 12 chars + "...")
- Exit 0 on success; exit 1 on fail

## Verification

### Test 1: Clear env vars, then run pazar_spine_check

```powershell
# Clear environment variables
Remove-Item Env:PRODUCT_TEST_AUTH -ErrorAction SilentlyContinue
Remove-Item Env:HOS_TEST_AUTH -ErrorAction SilentlyContinue

# Run pazar_spine_check (should bootstrap token automatically)
.\ops\pazar_spine_check.ps1
```

**Expected Result:**
- Reservation Contract Check should bootstrap token automatically (or tell user to run ensure script)
- No "Duration property cannot be found" or similar StrictMode/property errors
- Exits 0 only when all checks PASS; exits 1 on any FAIL

### Test 2: ensure_product_test_auth.ps1 standalone

```powershell
.\ops\ensure_product_test_auth.ps1
```

**Expected Result:**
- Bootstraps token successfully
- Prints "OK: PRODUCT_TEST_AUTH set for this process"
- Prints redacted token preview (first 12 chars + "...")
- Does NOT print full JWT
- Exit 0 on success

### Test 3: pazar_spine_check summary (no Duration errors)

**Before WP-23:**
```
WARN: pazar_spine_check error (continuing): The property 'Duration' cannot be found on this object.
```

**After WP-23:**
```
=== PAZAR SPINE CHECK SUMMARY ===
  PASS: World Status Check (WP-1.2) (6.89s)
  PASS: Catalog Contract Check (WP-2) (3.57s)
  PASS: Listing Contract Check (WP-3) (4.37s)
  PASS: Reservation Contract Check (WP-4) (2.15s)
```

No property errors. All DurationSec values properly set.

## Validation

✅ **No secrets committed:** Full JWT never printed (only redacted preview)  
✅ **Minimal diffs:** Only auth acquisition/validation changes, no route behavior changes  
✅ **PowerShell 5.1 compatible:** Uses standard cmdlets, no PS 7+ features  
✅ **ASCII-only outputs:** No Unicode characters in output  
✅ **Zero domain refactor:** No API endpoints or domain logic changed  
✅ **Deterministic:** Bootstrap token works consistently when H-OS is available  
✅ **Fail-fast:** Clear error messages with remediation steps

## Notes

- Bootstrap token requires H-OS service to be running
- If H-OS is not available, scripts will fail with clear remediation messages
- Token is set in environment variables for current PowerShell session only
- To persist across sessions, set in shell profile or use `$env:PRODUCT_TEST_AUTH = 'Bearer <token>'`

## Files Changed

- `ops/_lib/test_auth.ps1` (NEW)
- `ops/ensure_product_test_auth.ps1` (NEW)
- `ops/reservation_contract_check.ps1` (MOD)
- `ops/rental_contract_check.ps1` (MOD)
- `ops/order_contract_check.ps1` (MOD)
- `ops/pazar_spine_check.ps1` (MOD)

## Acceptance Criteria (HARD)

✅ Running `.\ops\pazar_spine_check.ps1` in a fresh shell with no PRODUCT_TEST_AUTH:
   - Bootstraps token automatically (or tells user to run ensure script), then Reservation check PASS
   - No "Duration property cannot be found" or similar StrictMode/property errors
   - Exits 0 only when all checks PASS; exits 1 on any FAIL

✅ No secrets committed; full JWT never printed

✅ Minimal diffs; no route behavior changes

---

**WP-23 COMPLETE** ✅

