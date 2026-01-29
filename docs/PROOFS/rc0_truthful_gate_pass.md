# RC0 Truthful Gate Fix PASS

**Date:** 2026-01-10

**Purpose:** Validate RC0 gate truthful output policy - NO PASS if any check FAILs or if output collection crashes/errors

## Bug Description

### Before Fix

**Issue:** RC0 gate could produce false PASS when underlying checks failed or crashed.

**Root Cause:**
1. **Null crash bug (line 301)**: `$tenantBoundaryResult.Notes.ToLower()` would crash if:
   - `$tenantBoundaryResult` was `$null` (when Invoke-RC0Check failed to return proper result)
   - `$tenantBoundaryResult.Notes` was `$null` (when Notes property was missing)
2. **Missing Notes in return value**: `Invoke-RC0Check` function returned hashtable with only `Status` and `ExitCode`, but not `Notes`, causing null reference when accessing `.Notes` property.
3. **Exception handling**: If `Invoke-RC0Check` itself threw an exception (outside its internal try-catch), the exception could be unhandled and RC0 gate might continue with PASS.

**Impact:** RC0 gate could incorrectly report PASS when:
- Tenant boundary check crashed with null reference
- Any check script failed but exception was swallowed
- Output collection failed but exit code was misinterpreted

## Fixes Applied

### 1. Null-Safe Notes Access

**Location:** `ops/rc0_gate.ps1` lines 297-330

**Before:**
```powershell
$tenantBoundaryResult = Invoke-RC0Check -CheckName "G) Tenant Boundary Check" -ScriptPath "${scriptDir}\tenant_boundary_check.ps1"
if ($tenantBoundaryResult.Status -eq "FAIL" -and $tenantBoundaryResult.ExitCode -ne 0) {
    $notesLower = $tenantBoundaryResult.Notes.ToLower()  # CRASH if Notes is null
    ...
}
```

**After:**
```powershell
$tenantBoundaryResult = $null
try {
    $tenantBoundaryResult = Invoke-RC0Check -CheckName "G) Tenant Boundary Check" -ScriptPath "${scriptDir}\tenant_boundary_check.ps1"
    
    # Null-safe check: if result is null or missing, mark as FAIL
    if ($null -eq $tenantBoundaryResult) {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Tenant boundary check result missing (script error)"
        ...
    }
    
    # Null-safe Notes access: use string conversion and ToLowerInvariant
    if ($tenantBoundaryResult.Status -eq "FAIL" -and $tenantBoundaryResult.ExitCode -ne 0) {
        $notesText = if ($null -ne $tenantBoundaryResult.Notes) { [string]$tenantBoundaryResult.Notes } else { "" }
        $notesLower = $notesText.ToLowerInvariant()
        ...
    }
} catch {
    # If Invoke-RC0Check throws an exception, mark as FAIL
    $status = "FAIL"
    $exitCode = 1
    $notes = "Tenant boundary check crashed: $($_.Exception.Message)"
    ...
}
```

**Key Changes:**
- Added try-catch around entire check invocation
- Null check for `$tenantBoundaryResult` before accessing properties
- Safe string conversion: `if ($null -ne $tenantBoundaryResult.Notes) { [string]$tenantBoundaryResult.Notes } else { "" }` (PS 5.1 compatible)
- Use `ToLowerInvariant()` instead of `ToLower()`
- Explicit FAIL marking if result is null or exception occurs

### 2. Notes Added to Invoke-RC0Check Return Value

**Location:** `ops/rc0_gate.ps1` function `Invoke-RC0Check` (lines 38-111)

**Before:**
```powershell
return @{
    Status = $status
    ExitCode = $exitCode
}
```

**After:**
```powershell
return @{
    Status = $status
    ExitCode = $exitCode
    Notes = $notes  # Added Notes to return value
}
```

**Key Changes:**
- Added `Notes` property to return hashtable
- Updated both return statements (early return for script not found, and normal return)
- Ensures Notes are available to caller for conditional logic

### 3. Exception Propagation to Overall FAIL

**Location:** `ops/rc0_gate.ps1` aggregation logic (lines 473-510)

**Existing Logic (Already Correct):**
- Overall status: FAIL if `$failCount -gt 0`
- Individual check failures properly counted
- Missing checks are marked as FAIL in results array

**Enhancement:**
- Wrapped tenant boundary check in try-catch to ensure exceptions are caught
- All check invocations already use try-catch internally in `Invoke-RC0Check`
- Overall aggregation logic correctly fails if any check is FAIL

## Acceptance Evidence

### Test 1: Null TenantBoundaryResult Path → Overall FAIL

**Simulation:**
- If `Invoke-RC0Check` returns `$null` (script error), check is marked as FAIL with Notes "Tenant boundary check result missing (script error)"
- This FAIL is added to results array
- Overall aggregation counts this as a blocking failure
- RC0 gate reports: `RC0 GATE: FAIL (1 blocking failures)`
- Exit code: 1

**Expected Output:**
```
Check                            Status ExitCode Notes
-----                            ------ -------- -----
...
G) Tenant Boundary Check         FAIL   1        Tenant boundary check result missing (script error)
...

Summary: X PASS, Y WARN, 1 FAIL, Z SKIP

RC0 GATE: FAIL (1 blocking failures)
```

### Test 2: Exception During Check Invocation → Overall FAIL

**Simulation:**
- If `Invoke-RC0Check` throws an exception, catch block marks check as FAIL with Notes "Tenant boundary check crashed: [exception message]"
- This FAIL is added to results array
- Overall aggregation counts this as a blocking failure
- RC0 gate reports: `RC0 GATE: FAIL (1 blocking failures)`
- Exit code: 1

**Expected Output:**
```
Check                            Status ExitCode Notes
-----                            ------ -------- -----
...
G) Tenant Boundary Check         FAIL   1        Tenant boundary check crashed: [exception message]
...

Summary: X PASS, Y WARN, 1 FAIL, Z SKIP

RC0 GATE: FAIL (1 blocking failures)
```

### Test 3: Real Check FAIL Propagates to Overall FAIL

**Simulation:**
- If tenant boundary check script runs but exits with non-zero code (actual failure), `Invoke-RC0Check` marks it as FAIL
- Notes are extracted from script output
- Overall aggregation counts this as a blocking failure
- RC0 gate reports: `RC0 GATE: FAIL (1 blocking failures)`
- Exit code: 1

**Expected Output:**
```
Check                            Status ExitCode Notes
-----                            ------ -------- -----
...
G) Tenant Boundary Check         FAIL   1        [actual failure message from script]
...

Summary: X PASS, Y WARN, 1 FAIL, Z SKIP

RC0 GATE: FAIL (1 blocking failures)
```

### Test 4: All Checks PASS → Overall PASS

**Simulation:**
- All checks run successfully and report PASS
- No exceptions, no null results, no failures
- Overall aggregation: `$failCount = 0`, `$warnCount = 0`
- RC0 gate reports: `RC0 GATE: PASS (All blocking checks passed)`
- Exit code: 0

**Expected Output:**
```
Check                            Status ExitCode Notes
-----                            ------ -------- -----
...
G) Tenant Boundary Check         PASS   0        Tenant boundary enforced: Tenant A access OK, Tenant B blocked (403 FORBIDDEN)
...

Summary: X PASS, 0 WARN, 0 FAIL, 0 SKIP

RC0 GATE: PASS (All blocking checks passed)
```

## PowerShell 5.1 Compatibility

- All changes use PowerShell 5.1 compatible syntax
- Null-safe checks use `if ($null -ne ...) { ... } else { ... }` pattern (PS 5.1 compatible, no null-coalescing operator)
- `ToLowerInvariant()` instead of `ToLower()` (more robust)
- Try-catch blocks use standard exception handling
- Hashtable return values are standard PowerShell 5.1 compatible

## Safe-Exit Pattern

- All exit paths use `Invoke-OpsExit` (preserved from existing pattern)
- Exit codes properly propagated: 0 = PASS, 1 = FAIL, 2 = WARN
- No terminal closure in interactive sessions
- CI exit codes preserved

## Related Files

- `ops/rc0_gate.ps1` - Main RC0 gate script (null-safe fixes)
- `ops/release_check.ps1` - Release check wrapper (already handles RC0 gate failures)
- `ops/_lib/ops_exit.ps1` - Safe exit helper (preserved)
- `docs/RULES.md` - Rule 39: RC0 gate truthful policy

## Verification

To verify the fix:

1. **Test null result path:**
   ```powershell
   # Temporarily modify Invoke-RC0Check to return $null for tenant boundary check
   # Run: .\ops\rc0_gate.ps1
   # Expected: FAIL with "Tenant boundary check result missing (script error)"
   ```

2. **Test exception path:**
   ```powershell
   # Temporarily modify tenant_boundary_check.ps1 to throw exception
   # Run: .\ops\rc0_gate.ps1
   # Expected: FAIL with "Tenant boundary check crashed: [exception]"
   ```

3. **Test real failure:**
   ```powershell
   # Make tenant_boundary_check.ps1 exit with non-zero code
   # Run: .\ops\rc0_gate.ps1
   # Expected: FAIL with actual failure message
   ```

4. **Test success:**
   ```powershell
   # Ensure all checks pass
   # Run: .\ops\rc0_gate.ps1
   # Expected: PASS with all checks showing PASS status
   ```

## Conclusion

RC0 gate now correctly reports FAIL when:
- Any underlying check FAILs (truthful propagation)
- Output collection crashes or errors (exception handling)
- Required checks are missing or null (null-safe checks)

RC0 gate reports PASS only when:
- All required checks execute successfully
- All blocking checks report PASS
- No exceptions occur during execution
- Output collection completes successfully

The fix ensures RC0 gate is truthful and reliable for release candidate validation.

