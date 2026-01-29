# WP-45: Ship Main - Proof Document

**Timestamp:** 2026-01-22  
**Purpose:** One command publish: gates + smokes + push (no PR, no branch)

---

## Command Run

```powershell
.\ops\ship_main.ps1
```

## Output

(Note: Output will be captured when script runs successfully. This proof document will be updated with actual test results after validation.)

---

## Expected Flow

1. **Pre-flight:** Check current branch is main, working tree is clean
2. **Gates:** Run all gates in order (fail-fast):
   - secret_scan.ps1
   - public_ready_check.ps1
   - conformance.ps1
   - frontend_smoke.ps1
   - prototype_smoke.ps1
   - prototype_flow_smoke.ps1
3. **Git Sync:** Pull with rebase, push to origin/main
4. **Summary:** Print PASS summary

---

## Validation

- All gates must PASS
- Git sync must succeed
- Exit code: 0
- ASCII-only output

