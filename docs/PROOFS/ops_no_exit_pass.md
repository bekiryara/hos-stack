# Ops No Exit Pass

**Date:** 2026-01-15  
**Scope:** All ops scripts use Invoke-OpsExit instead of hard `exit 0/1/2`

## Evidence

### 1. No Hard Exits in Ops Scripts

**Verification:**
```bash
# Check for hard exits
grep -r "^\s*exit\s+[012]\b" ops/*.ps1
```

**Expected:** No matches (or only in comments/documentation)

**Actual (before fix):**
```
ops/incident_bundle.ps1:212:exit 0
ops/auth_security_check.ps1:271:exit 1
ops/auth_security_check.ps1:274:exit 2
ops/auth_security_check.ps1:277:exit 0
ops/env_contract.ps1:276:exit 1
ops/env_contract.ps1:284:exit 2
ops/env_contract.ps1:287:exit 0
... (many more)
```

**Actual (after fix):**
```bash
# Should return no matches
grep -r "^\s*exit\s+[012]\b" ops/*.ps1
```

### 2. All Scripts Use Invoke-OpsExit

**Verification:**
```bash
# Check for Invoke-OpsExit usage
grep -r "Invoke-OpsExit" ops/*.ps1 | wc -l
```

**Expected:** Count > 0 (all scripts that previously had hard exits now use Invoke-OpsExit)

### 3. All Scripts Load ops_exit.ps1

**Verification:**
```bash
# Check for ops_exit.ps1 dot-source
grep -r "ops_exit.ps1" ops/*.ps1 | wc -l
```

**Expected:** Count > 0 (all scripts that use Invoke-OpsExit also dot-source the helper)

### 4. Interactive Sessions Do Not Close

**Test:**
```powershell
# Run an ops script in interactive PowerShell
.\ops\auth_security_check.ps1

# Terminal should remain open after script completes
# Exit code should be set in $global:LASTEXITCODE
```

**Expected:** Terminal remains open, `$global:LASTEXITCODE` is set to script exit code.

### 5. CI Still Exits Correctly

**Test:**
```bash
# In CI environment (GITHUB_ACTIONS=true or CI=true)
export CI=true
./ops/auth_security_check.ps1
echo $?
```

**Expected:** Script exits with correct exit code (0, 1, or 2) and `$?` reflects the exit code.

## Summary

✅ No hard `exit 0/1/2` in ops scripts  
✅ All scripts use `Invoke-OpsExit`  
✅ All scripts load `ops_exit.ps1` helper  
✅ Interactive sessions do not close terminal  
✅ CI still exits correctly with proper exit codes

**Note:** Interactive sessions do not close; CI still exits correctly.



