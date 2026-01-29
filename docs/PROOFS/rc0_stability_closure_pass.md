# RC0 Stability Closure Pack v1 PASS

**Date:** 2026-01-XX

**Purpose:** Eliminate remaining "drift/parse/404" class failures in RC0 gates.

## Evidence Items

### 1. /metrics at Root Returns 200 with Prometheus Format

**Test:**
```powershell
curl.exe -sS -i http://localhost:8080/metrics
```

**Expected:**
- HTTP 200 OK
- Content-Type: `text/plain; version=0.0.4; charset=utf-8`
- Cache-Control: `no-store`
- Body includes baseline metrics:
  - `pazar_build_info{service="pazar",version="..."} 1`
  - `pazar_time_seconds <unix_float>`
  - `pazar_php_memory_usage_bytes <int>`
  - `pazar_php_memory_peak_bytes <int>`

**Result:** ✅ PASS - /metrics at root returns 200 with correct Content-Type and baseline metrics.

### 2. Conformance World Registry Drift Check No Longer False Positive

**Test:**
```powershell
.\ops\conformance.ps1
```

**Expected:**
- World registry drift check PASS when WORLD_REGISTRY.md and config/worlds.php match
- Only parses lines between "### Enabled Worlds" and "### Disabled Worlds" sections
- Only parses lines after "### Disabled Worlds" until EOF
- No false positives from Markdown tables or other sections

**Result:** ✅ PASS - Conformance correctly parses world registry sections and compares with config.

### 3. Product/World Gates Parse Enabled Worlds Correctly

**Test:**
```powershell
.\ops\world_spine_check.ps1
.\ops\product_read_path_check.ps1
.\ops\product_spine_governance.ps1
```

**Expected:**
- All gates correctly detect enabled worlds from worlds.php
- No "No enabled worlds found" errors
- Parsing works on PowerShell 5.1 without PHP execution
- Multiline arrays handled correctly

**Result:** ✅ PASS - All gates use Get-WorldsConfig parser and correctly detect enabled/disabled worlds.

### 4. Interactive Shells Do Not Close (Safe Exit)

**Test:**
```powershell
# Run any affected script in interactive PowerShell
.\ops\conformance.ps1
.\ops\world_spine_check.ps1
.\ops\product_read_path_check.ps1
.\ops\product_spine_governance.ps1
```

**Expected:**
- Scripts use Invoke-OpsExit (not hard exit)
- Terminal stays open after script completes
- Exit codes still propagate correctly in CI

**Result:** ✅ PASS - All scripts use Invoke-OpsExit, terminal does not close in interactive mode.

### 5. ASCII-Only Output Markers

**Test:**
```powershell
.\ops\conformance.ps1 | Select-String -Pattern "\[PASS\]|\[FAIL\]|\[WARN\]|\[INFO\]"
```

**Expected:**
- All output uses ASCII markers: [PASS], [FAIL], [WARN], [INFO]
- No Unicode glyphs (✅, ❌, ⚠️, ✓, ✗, ➕, ➖)

**Result:** ✅ PASS - All scripts use ASCII-only markers via ops_output.ps1 helpers.

## Files Changed

- `work/pazar/routes/web.php` - Added GET /metrics at root
- `work/pazar/routes/api.php` - Removed /api/metrics route (single canonical at root)
- `work/pazar/app/Http/Controllers/MetricsController.php` - Added token support, baseline metrics
- `ops/_lib/worlds_config.ps1` - NEW: Canonical worlds.php parser
- `ops/conformance.ps1` - Fixed world registry parsing, uses Get-WorldsConfig
- `ops/world_spine_check.ps1` - Uses Get-WorldsConfig, ASCII-only output
- `ops/product_read_path_check.ps1` - Uses Get-WorldsConfig
- `ops/product_spine_governance.ps1` - Uses Get-WorldsConfig, ASCII-only output
- `ops/ops_status.ps1` - Added rc0_check to registry

## Acceptance Criteria

✅ /metrics at root no longer 404 and serves baseline metrics with correct Content-Type  
✅ conformance world drift check produces correct PASS when registry and config match  
✅ world/product gates parse enabled/disabled worlds reliably on PowerShell 5.1  
✅ No Unicode in ops outputs; safe exit preserved; interactive PowerShell never closes  
✅ No changes to DB schema; no disabled-world code introduced; existing governance remains PASS

**Result:** ✅ RC0 Stability Closure Pack v1 PASS - All drift/parse/404 failures eliminated, gates are reliable and deterministic.























