# Release Bundle Pass

**Date:** 2026-01-10

**Purpose:** Verify RC0 release bundle generator creates timestamped zip with all required evidence.

---

## Command

```powershell
.\ops\release_bundle.ps1
```

---

## Expected Output

```
=== RC0 RELEASE BUNDLE GENERATOR ===
Timestamp: 2026-01-10 12:00:00

Creating release bundle: _archive\releases\release-20260110-120000

=== Collecting Git Status ===
  [PASS] Git working directory clean

=== Collecting Ops Evidence ===
Capturing Doctor output...
  [PASS] outputs\doctor_output.txt
Capturing Verify output...
  [PASS] outputs\verify_output.txt
Capturing Ops Status output...
  [PASS] outputs\ops_status_output.txt
Capturing Observability Status output...
  [PASS] outputs\observability_status_output.txt

=== Collecting Snapshots ===
  [OK] routes.pazar.json
  [OK] schema.pazar.sql

=== Collecting Version Info ===
  [OK] version.txt
Collecting CHANGELOG [Unreleased] section...
  [OK] changelog_unreleased.txt

=== Creating Source Manifest ===
  [OK] source_manifest.txt

=== Creating Zip Archive ===
  [OK] _archive\releases\release-20260110-120000.zip
  [INFO] Zip size: 125.5 KB

=== RELEASE BUNDLE COMPLETE ===

Bundle folder: _archive\releases\release-20260110-120000
Bundle zip: _archive\releases\release-20260110-120000.zip
Files collected: 10

RELEASE_BUNDLE_PATH=_archive\releases\release-20260110-120000
RELEASE_BUNDLE_ZIP=_archive\releases\release-20260110-120000.zip
OVERALL STATUS: PASS
```

---

## Files Created in Bundle

**Folder:** `_archive/releases/release-YYYYMMDD-HHMMSS/`

**Contents:**
1. `meta.txt` - Git status, branch, commit, last tag
2. `outputs/doctor_output.txt` - Repository doctor output
3. `outputs/verify_output.txt` - Stack verification output
4. `outputs/ops_status_output.txt` - Unified ops status dashboard output
5. `outputs/observability_status_output.txt` - Observability status output (if available)
6. `snapshots/routes.pazar.json` - Route snapshot
7. `snapshots/schema.pazar.sql` - Schema snapshot
8. `version.txt` - VERSION file contents
9. `changelog_unreleased.txt` - CHANGELOG.md [Unreleased] section excerpt
10. `source_manifest.txt` - List of tracked files (git ls-files output)

**Zip:** `_archive/releases/release-YYYYMMDD-HHMMSS.zip`

- Contains all files from bundle folder
- Compressed using PowerShell Compress-Archive
- Size: typically 100-500 KB (depends on ops output size)

---

## Exit Codes

**PASS (0):**
- All blocking checks PASS (doctor, verify, ops_status)
- Bundle zip created successfully
- Git working directory clean

**WARN (2):**
- No FAIL, but warnings present:
  - Git working directory not clean
  - Missing optional files (VERSION, snapshots, CHANGELOG [Unreleased])
  - Observability status unavailable

**FAIL (1):**
- Blocking check FAIL (doctor/verify/ops_status failed)
- Bundle creation failed

---

## Notes

- **Bundles are untracked**: All bundle artifacts are in `_archive/releases/` which is gitignored
- **Source manifest**: Lists tracked files only (git ls-files), does not include secrets, .env, storage logs, or untracked files
- **Snapshot scripts**: Routes and schema snapshots are copied from `ops/snapshots/` (not regenerated during bundle creation)
- **CHANGELOG extraction**: Uses regex to extract `[Unreleased]` section from CHANGELOG.md
- **PowerShell 5.1 compatible**: Uses Compress-Archive (no .NET ZipFile fallback needed)
- **Safe exit**: Uses Invoke-OpsExit to prevent terminal closure in interactive mode

---

## Verification

**Verify bundle contents:**
```powershell
# Extract zip to inspect
Expand-Archive -Path _archive\releases\release-YYYYMMDD-HHMMSS.zip -DestinationPath _temp\bundle_check -Force

# Check files
Get-ChildItem -Path _temp\bundle_check -Recurse | Select-Object FullName, Length
```

**Verify git status:**
```powershell
# Bundle folder and zip should NOT be tracked
git status _archive\releases\
# Should show: nothing to commit (or untracked files if git status includes untracked)
```





