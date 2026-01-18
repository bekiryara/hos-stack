# Final Sanity Runner - Proof

**Timestamp:** 2026-01-18  
**Command:** `.\ops\final_sanity.ps1`  
**WP:** WP-NEXT Final Sanity Runner (Canonical)

## What Was Added

1. **ops/final_sanity.ps1** (NEW)
   - Canonical runner for release-grade checks
   - Parameters: `-NoPause`, `-SkipFrontend` (default: true)
   - Evidence logging to `docs/PROOFS/_runs/final-sanity-YYYYMMDD-HHMMSS/`
   - Runs checks:
     - `.\ops\world_status_check.ps1`
     - `.\ops\pazar_spine_check.ps1`
     - `.\ops\read_snapshot_check.ps1` (if exists, else FAIL)
     - Frontend build (if `-SkipFrontend:$false` and `work/marketplace-web` exists)

2. **docs/PROOFS/_runs/** (NEW directory)
   - Evidence logs folder for all final sanity runs
   - Timestamped subfolders: `final-sanity-YYYYMMDD-HHMMSS/`

3. **.gitignore** (VERIFIED)
   - `_tmp*` already covered (line 41)
   - Evidence logs in `docs/PROOFS/_runs/` are tracked (not ignored)

## Exact Commands

```powershell
# Basic run (pauses at end)
.\ops\final_sanity.ps1

# Run without pause
.\ops\final_sanity.ps1 -NoPause

# Run with frontend build (skip default)
.\ops\final_sanity.ps1 -SkipFrontend:$false

# Combined
.\ops\final_sanity.ps1 -NoPause -SkipFrontend:$false
```

## Evidence Folder

Evidence logs are saved to:
- `docs/PROOFS/_runs/final-sanity-YYYYMMDD-HHMMSS/`

Each run creates a timestamped folder containing:
- `world_status_check.txt` - World status check output
- `pazar_spine_check.txt` - Pazar spine check output
- `read_snapshot_check.txt` - Read snapshot check output
- `frontend_build.txt` - Frontend build output (if enabled)

## Behavior

1. **Pause Implementation:**
   - Uses `Read-Host "Press Enter to exit"` (PowerShell 5.1 compatible)
   - Skipped when `-NoPause` is provided
   - Window does NOT auto-close

2. **Exit Codes:**
   - `0` if all checks PASS
   - `1` if any check FAIL

3. **Evidence Logging:**
   - All script outputs (stdout+stderr) captured to evidence files
   - ASCII-only encoding
   - Evidence folder path printed in summary

4. **Read Snapshot Check:**
   - If `read_snapshot_check.ps1` not found, runner FAILS with clear message
   - Evidence file still created with error message

## Summary Output Example

```
=== FINAL SANITY RUNNER SUMMARY ===
Evidence folder: D:\stack\docs\PROOFS\_runs\final-sanity-20260118-120000

  PASS: World Status Check (2.45s) -> world_status_check.txt
  PASS: Pazar Spine Check (15.32s) -> pazar_spine_check.txt
  PASS: Read Snapshot Check (1.23s) -> read_snapshot_check.txt
  [SKIP] Frontend Build (SkipFrontend=true)

=== FINAL SANITY RUNNER: PASS ===
All checks passed. Evidence logs saved in:
  D:\stack\docs\PROOFS\_runs\final-sanity-20260118-120000
```

## PowerShell 5.1 Compatibility

- Uses `Read-Host` instead of `[Console]::ReadLine()` without `::` (avoids parse errors)
- Process.StartInfo pattern for child process execution
- ASCII-only output (no unicode icons)
- Minimal parsing dependencies

## Repo Hygiene

- `_tmp*` files already ignored in `.gitignore` (line 41)
- Evidence logs in `docs/PROOFS/_runs/` are tracked (not ignored)
- Script does NOT touch vendor contents
- `git status --porcelain` must be empty at end

## Validation

- [x] Script created: `ops/final_sanity.ps1`
- [x] PowerShell 5.1 compatible (Read-Host pattern)
- [x] Pause implementation correct (no parse errors)
- [x] Evidence folder structure created
- [x] Exit codes correct (0 PASS, 1 FAIL)
- [x] Evidence logs written (ASCII-only)
- [x] .gitignore verified (`_tmp*` covered)

## Conclusion

Final Sanity Runner successfully created. Canonical runner for release-grade checks with evidence logging. PowerShell 5.1 compatible, no parse errors, window does not auto-close (pause at end). Evidence logs saved deterministically in timestamped folders.


