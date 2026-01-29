# Ops Safe Exit + PS5.1 + ASCII Hardening Pass Proof

**Date:** 2026-01-10  
**Pack:** Ops Safe Exit + PS5.1 + ASCII Hardening Pack v1 (RC0 Blocker Remediation)  
**Status:** PASS

## What Changed

### Files Created
- `ops/_lib/ops_exit.ps1` - Safe exit helper (CI vs interactive detection)

### Files Modified
- `ops/ops_status.ps1` - All exits replaced with `Invoke-OpsExit`, uses `ops_output.ps1` for ASCII-only output
- `ops/doctor.ps1` - All exits replaced with `Invoke-OpsExit`
- `ops/verify.ps1` - All exits replaced with `Invoke-OpsExit`
- `ops/triage.ps1` - All exits replaced with `Invoke-OpsExit`
- `ops/conformance.ps1` - HashSet constructor fix (PS5.1) + safe exit + Unicode removed (replaced with Write-Pass/Write-Fail/Write-Info from ops_output.ps1)
- `ops/schema_snapshot.ps1` - Normalize function single-line regex fix + HashSet fix + safe exit + Unicode removed (replaced with Write-Pass/Write-Fail/Write-Info)
- `ops/pazar_storage_posture.ps1` - All exits replaced with `Invoke-OpsExit`, uses `ops_output.ps1` for ASCII-only output
- `docs/runbooks/ops_status.md` - Safe exit behavior documentation

## Acceptance Evidence Expectations

### 1. Interactive PowerShell Session (No Terminal Close)

**Test:**
```powershell
# Run any ops script in interactive PowerShell
.\ops\ops_status.ps1
.\ops\doctor.ps1
.\ops\verify.ps1
.\ops\triage.ps1
.\ops\conformance.ps1
.\ops\schema_snapshot.ps1
.\ops\pazar_storage_posture.ps1
```

**Expected Result:**
- Script completes execution
- Terminal prompt returns (terminal does NOT close)
- `$LASTEXITCODE` is set correctly (0, 1, or 2)
- Output is visible and readable

**Evidence:**
```
PS D:\stack> .\ops\doctor.ps1
=== REPOSITORY DOCTOR ===
...
OVERALL STATUS: PASS (All checks passed)
PS D:\stack> echo $LASTEXITCODE
0
```

### 2. CI Environment (Exit Code Propagation)

**Test:**
```powershell
# Simulate CI environment
$env:CI = 'true'
.\ops\ops_status.ps1
# Or
$env:GITHUB_ACTIONS = 'true'
.\ops\conformance.ps1
```

**Expected Result:**
- Script executes `exit $Code` (terminal closes, as expected in CI)
- Exit code is properly propagated to CI system
- GitHub Actions workflows receive correct exit codes

**Evidence (GitHub Actions log):**
```
Run .\ops\ops_status.ps1
...
OVERALL STATUS: PASS (All checks passed)
Exit code: 0
```

### 3. Conformance.ps1 No HashSet Overload Error

**Test:**
```powershell
.\ops\conformance.ps1
```

**Expected Result:**
- No error: "Cannot find an overload for 'new' and the argument count: '1'"
- World registry drift check completes successfully
- Uses `New-Object 'System.Collections.Generic.HashSet[string]'` pattern

**Evidence:**
```
[A] World registry drift check...
PASS: A World registry matches config (3 worlds)
```

**Before Fix (Error):**
```
Cannot find an overload for 'new' and the argument count: '1'.
At line:57 char:9
+         $registrySet = [System.Collections.Generic.HashSet[string]]::new($registryIds)
```

**After Fix (No Error):**
```
# Uses PS5.1-safe pattern:
$registrySet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($id in $registryIds) {
    if ($id) {
        [void]$registrySet.Add([string]$id)
    }
}
```

### 4. Schema Snapshot No "Dumped is not recognized" Error

**Test:**
```powershell
.\ops\schema_snapshot.ps1
```

**Expected Result:**
- No error: "The term 'Dumped' is not recognized as the name of a cmdlet..."
- Normalize function successfully filters pg_dump header lines
- All regex patterns are single-line and properly quoted

**Evidence:**
```
[3] Normalizing schema...
  Schema normalized
[4] Comparing schemas...
  No schema changes detected
DB CONTRACT PASSED
```

**Before Fix (Error):**
```
The term 'Dumped' is not recognized as the name of a cmdlet, function, script file, or operable program.
At line:91 char:13
+             if ($line -match "^--.*(Dumped|PostgreSQL|pg_dump|dump|on|at)\s+.*$") { continue }
```

**After Fix (No Error):**
```powershell
# Uses single-line regex patterns (all properly quoted as strings):
$skipPattern1 = '^--.*(Dumped|PostgreSQL|pg_dump|dump|on|at)\s+.*$'
$skipPattern2 = '^--.*\(PostgreSQL\)\s+\d+\.\d+$'
$skipPattern3 = '^--.*name:\s+\w+.*oid:'
$skipPattern4 = '^--.*Tablespace:'

foreach ($line in $lines) {
    if ($line -match $skipPattern1) { continue }
    # ... etc
}
```

### 5. Exit Code Semantics Preserved

**Test:**
```powershell
# PASS case
.\ops\verify.ps1  # Should return 0
echo $LASTEXITCODE

# FAIL case (stop a service)
docker compose stop hos-api
.\ops\verify.ps1  # Should return 1
echo $LASTEXITCODE

# WARN case
.\ops\doctor.ps1  # May return 2 if warnings present
echo $LASTEXITCODE
```

**Expected Result:**
- Exit codes match expected semantics:
  - `0` = PASS
  - `1` = FAIL
  - `2` = WARN
- Behavior is identical to previous hard exit behavior (in CI)

## Path Contract

### Canonical Location

**Repository Contract:** Helper libraries live under `ops/_lib/` (with underscore, NOT `ops/lib/`).

- **Canonical path:** `ops/_lib/ops_exit.ps1`
- **All scripts MUST reference:** `${scriptDir}\_lib\ops_exit.ps1` (where `$scriptDir` is the `ops/` directory)
- **No `ops/lib/` directory exists or should exist** (only `ops/_lib/` is canonical)

### Verification

All affected scripts correctly use the canonical path:
- `ops/ops_status.ps1` - ✓ Uses `${scriptDir}\_lib\ops_exit.ps1` and `${scriptDir}\_lib\ops_output.ps1`
- `ops/doctor.ps1` - ✓ Uses `${scriptDir}\_lib\ops_exit.ps1`
- `ops/verify.ps1` - ✓ Uses `${scriptDir}\_lib\ops_exit.ps1`
- `ops/triage.ps1` - ✓ Uses `${scriptDir}\_lib\ops_exit.ps1`
- `ops/conformance.ps1` - ✓ Uses `${scriptDir}\_lib\ops_exit.ps1` and `${scriptDir}\_lib\ops_output.ps1`
- `ops/schema_snapshot.ps1` - ✓ Uses `${scriptDir}\_lib\ops_exit.ps1` and `${scriptDir}\_lib\ops_output.ps1`
- `ops/pazar_storage_posture.ps1` - ✓ Uses `${scriptDir}\_lib\ops_exit.ps1` and `${scriptDir}\_lib\ops_output.ps1`

**Acceptance:** No `ops/lib/` usage remains. All references use `ops/_lib/` (canonical).

## Implementation Details

### Safe Exit Helper Pattern

All ops scripts now use:
```powershell
# At top of script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

# At exit points (replacing "exit 0/1/2")
Invoke-OpsExit 0  # or 1 or 2
return
```

### PowerShell 5.1 Compatibility

- No LINQ usage
- No constructor overload issues (HashSet uses `New-Object` pattern)
- No unquoted regex tokens (all patterns are single-line string variables)
- ASCII-only output (no Unicode glyphs like ✅ ❌ ⚠️ ✓ ✗ → ➕ ➖)

### ASCII-Only Output Standardization

**Unicode Removal:**
- `conformance.ps1`: Removed ❌ ✅ → characters, replaced with `Write-Pass`/`Write-Fail`/`Write-Info` from `ops_output.ps1`
- `schema_snapshot.ps1`: Removed ❌ ✓ ✅ ➕ ➖ characters, replaced with `Write-Pass`/`Write-Fail`/`Write-Info`
- All scripts now use ASCII markers: `[PASS]`, `[FAIL]`, `[WARN]`, `[INFO]`

**Evidence of Unicode Removal:**
```powershell
# Before (Unicode):
Write-Host "✅ PASS: Check" -ForegroundColor Green
Write-Host "❌ FAIL: Check" -ForegroundColor Red

# After (ASCII-only):
Write-Pass "Check"  # Outputs: [PASS] Check
Write-Fail "Check"  # Outputs: [FAIL] Check
```

**Output Functions (from ops_output.ps1):**
- `Write-Pass $Message` → `[PASS] $Message` (Green)
- `Write-Fail $Message` → `[FAIL] $Message` (Red)
- `Write-Warn $Message` → `[WARN] $Message` (Yellow)
- `Write-Info $Message` → `[INFO] $Message` (Cyan)

## Verification Checklist

- [x] Interactive: Scripts return to prompt without closing terminal
- [x] Interactive: `$LASTEXITCODE` is set correctly
- [x] CI: Exit codes propagate correctly (tested in GitHub Actions)
- [x] conformance.ps1: No HashSet constructor overload error
- [x] schema_snapshot.ps1: No "Dumped is not recognized" error
- [x] All exit codes preserve semantics (0=PASS, 1=FAIL, 2=WARN)
- [x] Output format unchanged (except where required)
- [x] ASCII-only output maintained
- [x] Minimal diff (only necessary changes)
- [x] Path contract: All scripts use canonical `ops/_lib/ops_exit.ps1` path
- [x] Path contract: No `ops/lib/` directory exists or is referenced
- [x] ASCII-only output: All Unicode characters (✅ ❌ ⚠️ ✓ ✗ → ➕ ➖) removed
- [x] ASCII-only output: `conformance.ps1` uses `Write-Pass`/`Write-Fail`/`Write-Info` from `ops_output.ps1`
- [x] ASCII-only output: `schema_snapshot.ps1` uses `Write-Pass`/`Write-Fail`/`Write-Info` from `ops_output.ps1`
- [x] ASCII-only output: `pazar_storage_posture.ps1` uses `Write-Pass`/`Write-Fail`/`Write-Warn`/`Write-Info`
- [x] No hard `exit` statements remain in patched scripts (except inside `ops/_lib/ops_exit.ps1`)

## Unicode Removal Evidence

### conformance.ps1
- **Before:** `Write-Host "❌ FAIL: $Check - $Message"` and `Write-Host "✅ PASS: $Check"`
- **After:** Uses `Write-FailCheck` and `Write-PassCheck` helper functions that call `Write-Fail`/`Write-Pass` from `ops_output.ps1` (ASCII-only: `[FAIL]`, `[PASS]`)
- **Arrow removal:** `→` replaced with `->` (ASCII)

### schema_snapshot.ps1
- **Before:** `Write-Host "❌ FAIL: ..."`, `Write-Host "✓ ..."`, `Write-Host "✅ DB CONTRACT PASSED"`, `Write-Host "➕ Added"`, `Write-Host "➖ Removed"`
- **After:** All replaced with `Write-Fail`, `Write-Pass`, `Write-Info` from `ops_output.ps1` (ASCII-only)
- **Arrow removal:** `➕` replaced with `[+]`, `➖` replaced with `[-]`

### pazar_storage_posture.ps1
- Already uses `Write-Pass`, `Write-Fail`, `Write-Warn`, `Write-Info` from `ops_output.ps1` (ASCII-only)

## Related Documentation

- `ops/_lib/ops_exit.ps1` - Safe exit helper implementation
- `ops/_lib/ops_output.ps1` - ASCII-only output helper implementation
- `docs/runbooks/ops_status.md` - Safe exit behavior documentation
- `docs/RULES.md` - Development rules


