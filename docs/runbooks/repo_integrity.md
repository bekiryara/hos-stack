# Repository Integrity Check - Handover Checklist

## Overview

The Repository Integrity check is exposed via `.\ops\ops.ps1 repo-integrity` (script: `ops/_checks/repo_integrity.ps1`). It performs non-destructive checks to detect repository drift, duplicate files, missing critical scripts, and unexpected untracked dumps. This runbook provides a handover checklist for repository health.

## What It Checks

1. **Massive Deleted-Tracked Files**: Detects if more than 10 tracked files are deleted (potential drift indicator)
2. **Unexpected Untracked Dumps**: Finds diagnostic/evidence files (`_diag_*`, `*_evidence_*.txt`, etc.) in root or non-archive locations
3. **Duplicate/Scratch Folders**: Detects folders like "Yeni klasör", "New Folder", "Copy", "Backup" that indicate manual file operations
4. **Duplicate Compose Files**: Checks for conflicting docker-compose.yml files (expected: root canonical, work/hos obs)
5. **Missing Critical Ops Scripts**: Verifies `ops_status.ps1`, `verify.ps1`, `doctor.ps1`, `triage.ps1` are present

## Running the Check

```powershell
.\ops\ops.ps1 repo-integrity
```

**Exit Codes:**
- `0` = PASS (no issues detected)
- `2` = WARN (minor issues, non-critical)
- `1` = FAIL (critical issues, e.g., missing ops scripts)

## Handover Checklist

Before handing over the repository to a new team member, ensure:

- [ ] `.\ops\ops.ps1 repo-integrity` returns PASS or WARN (not FAIL)
- [ ] No massive deleted-tracked files (>10 files)
- [ ] Unexpected untracked dumps moved to `_archive/` or added to `.gitignore`
- [ ] Duplicate/scratch folders removed or archived
- [ ] All critical ops scripts present and tracked
- [ ] Git status is clean (only intentional changes)

## Remediation Guidance

### If Massive Deleted Files Detected

```powershell
# Review deleted files
git status --short | Select-String "^D"

# Restore if needed
git restore <file>

# Or commit deletion if intentional
git add <file>
git commit -m "Remove <file> (intentional)"
```

### If Unexpected Untracked Dumps Found

```powershell
# Move to archive
Move-Item "_diag_*.txt" "_archive/$(Get-Date -Format 'yyyyMMdd')/diagnostics/" -ErrorAction SilentlyContinue

# Or add to .gitignore if temporary
Add-Content .gitignore "_diag_*.txt"
```

### If Duplicate Folders Found

```powershell
# Review and remove manually
Get-ChildItem -Path . -Directory -Filter "*Yeni klasör*" -Recurse

# Archive if needed
Move-Item "<duplicate-folder>" "_archive/$(Get-Date -Format 'yyyyMMdd')/duplicates/" -ErrorAction SilentlyContinue
```

### If Missing Critical Scripts

```powershell
# Restore from git history
git restore ops/<script-name>

# Or verify they exist in another location
git ls-files ops/*.ps1
```

## Integration

The integrity check is automatically called by Repository Doctor (`.\ops\ops.ps1 doctor`). It is WARN-only unless critical scripts are missing (FAIL).

## Related

- `.\ops\ops.ps1 doctor` - Comprehensive repository health check
- `docs/REPO_LAYOUT.md` - Repository structure contract
- `docs/RULES.md` - Development rules











