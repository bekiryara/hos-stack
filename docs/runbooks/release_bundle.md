# Release Bundle Runbook

**Purpose:** Create a deterministic, single-command RC0 release bundle artifact.

**Script:** `ops/release_bundle.ps1`

**Output:** Timestamped zip file with source snapshot, ops evidence, snapshots, and metadata.

---

## When to Run

Run `ops/release_bundle.ps1` before:
- Creating an RC0 tag
- Pushing to main (for release validation)
- Creating release notes for a PR

**Prerequisites:**
- Stack must be running (for ops checks: doctor, verify, ops_status)
- Git working directory should be clean (WARN if dirty)
- VERSION file should exist (WARN if missing)

---

## What It Produces

**Location:** `_archive/releases/release-YYYYMMDD-HHMMSS/` (folder) and `_archive/releases/release-YYYYMMDD-HHMMSS.zip` (zip)

**Contents:**

1. **meta.txt**: Git status, branch, commit, last tag
2. **outputs/**:
   - `doctor_output.txt`: Repository doctor output
   - `verify_output.txt`: Stack verification output
   - `ops_status_output.txt`: Unified ops status dashboard output
   - `observability_status_output.txt`: Observability status output (if available)
3. **snapshots/**:
   - `routes.pazar.json`: Route snapshot
   - `schema.pazar.sql`: Schema snapshot
4. **version.txt**: VERSION file contents
5. **changelog_unreleased.txt**: CHANGELOG.md [Unreleased] section excerpt
6. **source_manifest.txt**: List of tracked files (git ls-files output)

**Note:** Bundle artifacts are untracked (in `_archive/` which is gitignored).

---

## Usage

### Basic Usage

```powershell
# From repo root
.\ops\release_bundle.ps1
```

### CI Mode

```powershell
.\ops\release_bundle.ps1 -Ci
```

**Output:**
- Prints progress and status
- Creates folder and zip in `_archive/releases/`
- Prints final lines:
  - `RELEASE_BUNDLE_PATH=...`
  - `RELEASE_BUNDLE_ZIP=...`
  - `OVERALL STATUS: PASS/WARN/FAIL`

---

## Exit Codes

- **0 (PASS)**: All blocking checks PASS, bundle created successfully
- **2 (WARN)**: No FAIL, but one or more WARN (git dirty, missing optional files, non-blocking checks WARN)
- **1 (FAIL)**: Blocking check FAIL (doctor/verify/ops_status failed) or bundle creation failed

**Blocking checks (must PASS):**
- `doctor.ps1`: Repository health check
- `verify.ps1`: Stack verification
- `ops_status.ps1`: Unified ops status dashboard

**Non-blocking checks (WARN acceptable):**
- `observability_status.ps1`: Observability status (if service unavailable)
- Git working directory dirty (should be clean, but WARN only)
- Missing optional files (VERSION, snapshots, CHANGELOG [Unreleased] section)

---

## How to Attach Bundle to PR/Issue

1. **Run the script:**
   ```powershell
   .\ops\release_bundle.ps1
   ```

2. **Locate the zip file:**
   - Path is printed in output: `RELEASE_BUNDLE_ZIP=...`
   - Default location: `_archive/releases/release-YYYYMMDD-HHMMSS.zip`

3. **Attach to PR:**
   - Upload zip file as attachment to PR
   - Or copy zip path to PR description

4. **Attach to Issue:**
   - Upload zip file as attachment to GitHub issue
   - Or reference zip path in issue description

**Note:** Bundle zip files are untracked and should NOT be committed to git.

---

## How to Interpret PASS/WARN/FAIL

### PASS (Exit Code 0)

**Meaning:** All blocking checks passed, bundle created successfully.

**Next Steps:**
- Bundle is ready to attach to PR/issue
- Safe to proceed with RC0 tag creation

**What was captured:**
- Git status (clean)
- All ops evidence (doctor, verify, ops_status)
- All snapshots (routes, schema)
- Version and changelog excerpt

### WARN (Exit Code 2)

**Meaning:** No blocking failures, but warnings present.

**Common Warnings:**
- Git working directory not clean (uncommitted changes)
- Missing optional files (VERSION, snapshots, CHANGELOG [Unreleased])
- Observability status unavailable (service not running)

**Next Steps:**
- Review warnings
- Fix non-critical issues (e.g., commit uncommitted changes)
- Bundle is usable but may be incomplete
- Can proceed with RC0 tag after review

### FAIL (Exit Code 1)

**Meaning:** Blocking check failed or bundle creation failed.

**Common Failures:**
- `doctor.ps1` FAIL: Repository health issues
- `verify.ps1` FAIL: Stack verification failed (services down, health checks failed)
- `ops_status.ps1` FAIL: Unified ops status dashboard failed
- Zip creation failed: File system or permission issues

**Next Steps:**
- Fix blocking issues before proceeding
- Re-run release bundle after fixes
- DO NOT create RC0 tag until bundle generation PASS

---

## Troubleshooting

### Git Working Directory Not Clean

**Warning:** `[WARN] Git working directory not clean`

**Fix:**
```powershell
# Commit or stash changes
git status
git add .
git commit -m "Your commit message"
# Or
git stash
```

### Missing VERSION File

**Warning:** `[WARN] VERSION file not found`

**Fix:**
```powershell
# Create VERSION file with current version
echo "0.1.0" > VERSION
```

### Missing Snapshots

**Warning:** `[WARN] routes.pazar.json not found` or `[WARN] schema.pazar.sql not found`

**Fix:**
```powershell
# Generate routes snapshot
.\ops\routes_snapshot.ps1

# Generate schema snapshot
.\ops\schema_snapshot.ps1
```

### Stack Not Running

**Failure:** `verify.ps1` FAIL

**Fix:**
```powershell
# Start stack
docker compose up -d

# Wait for services to be healthy
.\ops\verify.ps1
```

### Zip Creation Failed

**Failure:** `[FAIL] Error creating zip`

**Possible Causes:**
- Insufficient disk space
- File permissions issue
- Path too long (Windows limitation)

**Fix:**
- Check disk space
- Run PowerShell as Administrator
- Use shorter path (move repo to shorter path)

---

## Related Scripts

- `ops/doctor.ps1`: Repository health diagnostics
- `ops/verify.ps1`: Stack verification
- `ops/ops_status.ps1`: Unified ops status dashboard
- `ops/release_check.ps1`: RC0 release checklist validation
- `ops/rc0_gate.ps1`: RC0 readiness gate

---

## Related Documentation

- `docs/RULES.md`: Release bundle rule (Rule 38)
- `docs/RELEASE_CHECKLIST.md`: Release checklist
- `docs/PROOFS/release_bundle_pass.md`: Proof documentation





