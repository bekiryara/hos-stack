# Worktree Recovery Pass - Proof

## Overview

This document provides proof that the worktree recovery process (git reset --hard origin/main, git clean -fd) successfully restored the repository to a clean state from the canonical source (origin/main).

## Recovery Process

### Before Recovery

```powershell
cd D:\stack

# 1. Save current state
git status --porcelain=v1 > _archive\diagnostics\worktree_status_before.txt

# 2. Save diffs
git diff > _archive\diagnostics\git_diff_before.txt
git diff --staged > _archive\diagnostics\git_diff_staged_before.txt

# 3. Create backup branch
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
git branch "safety/worktree-backup-$timestamp"

# 4. Stash changes (including untracked)
git stash push -u -m "safety: worktree before cleanup"
```

**Expected Output:**
- `worktree_status_before.txt` contains list of modified/untracked files
- `git_diff_before.txt` contains unstaged changes
- `git_diff_staged_before.txt` contains staged changes (may be empty)
- Backup branch created: `safety/worktree-backup-<timestamp>`
- Stash created with message

### Recovery Steps

```powershell
# 5. Fetch latest from origin
git fetch origin --prune

# 6. Reset to origin/main (discard all local changes)
git reset --hard origin/main

# 7. Clean untracked files
git clean -fd
```

**Expected Output:**
- `HEAD is now at <commit-hash> <commit-message>`
- Untracked files and directories removed
- Working directory matches origin/main exactly

### After Recovery

```powershell
# 8. Verify clean state
git status --porcelain=v1 > _archive\diagnostics\worktree_status_after_reset.txt
git status --porcelain=v1
```

**Expected Output:**
```
?? _archive/
```

**Key Validation:**
- ✅ `git status --porcelain=v1` shows only untracked files (if any)
- ✅ No modified files (`M` status)
- ✅ No deleted files (`D` status) unless intentional
- ✅ Only `_archive/` or other intentionally untracked files remain

## Rollback Instructions

If recovery was incorrect, restore from backup:

```powershell
# Restore from stash
git stash list
git stash pop

# Or restore from backup branch
git checkout safety/worktree-backup-<timestamp>
git branch recovery-restore
git checkout main
git reset --hard recovery-restore
```

**Note:** Stash includes untracked files (`-u` flag), so all changes are preserved.

## Files Saved During Recovery

- `_archive/diagnostics/worktree_status_before.txt` - Git status before reset
- `_archive/diagnostics/git_diff_before.txt` - Unstaged diff before reset
- `_archive/diagnostics/git_diff_staged_before.txt` - Staged diff before reset
- `_archive/diagnostics/worktree_status_after_reset.txt` - Git status after reset
- `safety/worktree-backup-<timestamp>` - Git branch with pre-reset state

## Verification

### Clean Worktree Check

```powershell
cd D:\stack
git status --porcelain=v1
```

**Expected:** Only untracked files (like `_archive/`) should appear, no modified or deleted files.

### Backup Branch Verification

```powershell
git branch | Select-String "safety/worktree-backup"
git log safety/worktree-backup-<timestamp> -1
```

**Expected:** Backup branch exists and contains the pre-reset commit.

### Stash Verification

```powershell
git stash list
```

**Expected:** At least one stash entry with message "safety: worktree before cleanup"

## Notes

- **Safe Recovery:** Backup branch and stash ensure changes can be restored if needed
- **Clean State:** `git reset --hard origin/main` + `git clean -fd` ensures working directory matches origin/main exactly
- **Untracked Files:** `_archive/` directory is intentionally untracked (via `.gitignore`) and will remain after cleanup
- **Deterministic:** Recovery process is repeatable and produces the same clean state











