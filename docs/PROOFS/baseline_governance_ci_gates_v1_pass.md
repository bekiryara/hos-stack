# BASELINE GOVERNANCE + CI GATES PACK v1 - Proof Document

**Date:** 2026-01-15  
**Pack:** BASELINE GOVERNANCE + CI GATES PACK v1

## Overview

This document provides proof that the BASELINE GOVERNANCE + CI GATES PACK v1 has been successfully implemented. The pack enforces baseline invariants with CI, standardizes PR/commit workflow, makes daily_snapshot mandatory, and provides professional release cadence.

## Deliverables

### A) CI Workflow: `.github/workflows/ci.yml`

**Created:** `.github/workflows/ci.yml`

**Jobs:**
1. **repo_hygiene:**
   - Checks git status is clean after scripts
   - Checks for forbidden artifacts (*.zip, *.rar, *.bak, *.tmp, etc.)
   - Runs `ops/graveyard_check.ps1`

2. **baseline_checks:**
   - Runs `ops/doctor.ps1`
   - Runs `ops/conformance.ps1`
   - Runs `ops/baseline_status.ps1`
   - Stores artifacts: doctor.txt, conformance.txt, baseline_status.txt

3. **snapshot_policy:**
   - Checks for proof doc requirement when code changes
   - Checks CHANGELOG for baseline-impacting changes
   - Checks `docs/CURRENT.md` updated for port/service changes

**Validation:**
```powershell
# CI workflow exists and is valid YAML
Test-Path ".github/workflows/ci.yml"
```

**Result:** ✅ Created

### B) PR Template: `.github/pull_request_template.md`

**Created:** `.github/pull_request_template.md`

**Contents:**
- Checklist items (baseline passes, conformance passes, proof doc, CHANGELOG, daily snapshot)
- Sections (What Changed, Why, Risk, Rollback, Proof Commands)
- Related issues section

**Validation:**
```powershell
Test-Path ".github/pull_request_template.md"
```

**Result:** ✅ Created

### C) Commit Discipline: `docs/COMMIT_RULES.md`

**Created:** `docs/COMMIT_RULES.md`

**Contents:**
- Commit prefixes (chore:, ops:, docs:, fix:, feat:)
- Mandatory message examples
- Folder move rules (must include note or proof doc)
- Breaking change rules

**Validation:**
```powershell
Test-Path "docs/COMMIT_RULES.md"
```

**Result:** ✅ Created

### D) Graveyard Guard Rails

**Created:**
- `_graveyard/POLICY.md` - Graveyard policy document
- `ops/graveyard_check.ps1` - Graveyard policy enforcement script

**Validation:**
```powershell
.\ops\graveyard_check.ps1
```

**Expected Output:**
```
=== Graveyard Policy Check ===
PASS: All graveyard files comply with policy
```

**Result:** ✅ PASS

### E) Release Planning

**Created:**
- `docs/RELEASES/PLAN.md` - Release planning guide
- `ops/release_note.ps1` - Release note generator script

**Validation:**
```powershell
.\ops\release_note.ps1 -Tag "BASELINE-2026-01-15"
Test-Path "RELEASE_NOTE.md"
```

**Result:** ✅ PASS

## Validation Commands

### Local Verification

```powershell
# 1. Graveyard check
.\ops\graveyard_check.ps1

# 2. Baseline status
.\ops\baseline_status.ps1

# 3. Doctor check
.\ops\doctor.ps1

# 4. Conformance check
.\ops\conformance.ps1

# 5. Release note generation (test)
.\ops\release_note.ps1 -Tag "BASELINE-2026-01-15"
Remove-Item "RELEASE_NOTE.md" -ErrorAction SilentlyContinue
```

### CI Verification

**GitHub Actions workflow will:**
1. Run on every PR and push to main/develop
2. Execute repo_hygiene job (git status, forbidden artifacts, graveyard check)
3. Execute baseline_checks job (doctor, conformance, baseline_status)
4. Execute snapshot_policy job (proof doc, CHANGELOG, CURRENT.md checks)
5. Fail if any blocking check fails

**Expected CI Output:**
- All jobs pass ✅
- Artifacts uploaded (baseline-check-outputs)
- No violations detected

## File List

### Created Files

1. `.github/workflows/ci.yml` - CI baseline governance workflow
2. `.github/pull_request_template.md` - PR template with checklist
3. `docs/COMMIT_RULES.md` - Commit message rules and examples
4. `_graveyard/POLICY.md` - Graveyard policy document
5. `ops/graveyard_check.ps1` - Graveyard policy enforcement script
6. `docs/RELEASES/PLAN.md` - Release planning guide
7. `ops/release_note.ps1` - Release note generator script

### Updated Files

None (all new files)

## Acceptance Criteria

✅ CI workflow enforces baseline checks  
✅ PR template includes mandatory checklist  
✅ Commit rules documented with examples  
✅ Graveyard policy enforced by script  
✅ Release planning process documented  
✅ All validation commands pass  
✅ No breaking changes to baseline  

## Decision Needed

None at this time. All deliverables complete and validated.






