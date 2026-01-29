# Release Runbook

## Overview

This runbook describes the RC0 release process, from pre-release validation to final tag creation. The process is automated where possible, with manual steps clearly marked.

## RC0 Release Sequence

### Step 1: Run RC0 Gate

**Purpose:** Validate all blocking checks for RC0 release readiness.

**Command:**
```powershell
.\ops\rc0_gate.ps1
```

**Expected Results:**
- **PASS (exit 0)**: All blocking checks passed → Proceed to Step 2
- **WARN (exit 2)**: Warnings present but no blocking failures → Review warnings, then proceed
- **FAIL (exit 1)**: Blocking failures detected → **STOP**. Fix failures before proceeding.

**What it checks:**
- Repository Doctor (Docker Compose services, health endpoints)
- Stack Verification (core services running and healthy)
- Architecture Conformance (world registry, forbidden artifacts, disabled-world code, canonical docs, secrets)
- Environment Contract (required env vars, production guardrails)
- Security Audit (route/middleware security violations)
- Auth Security Check (unauthorized access protection, rate limiting)
- Tenant Boundary Check (tenant isolation, secrets configuration)
- Session Posture Check (session cookie security flags)
- SLO Check (availability, p95 latency, error rate; p50 non-blocking)
- Error Contract (422/404 envelope validation)
- Observability Status (WARN only - optional for RC0)

**Remediation:** See `docs/runbooks/rc0_gate.md` for detailed remediation guidance.

---

### Step 2: Run Release Check

**Purpose:** Validate release prerequisites (git status, documentation, snapshots, version).

**Command:**
```powershell
.\ops\release_check.ps1
```

**Expected Results:**
- **PASS (exit 0)**: All prerequisites met → Proceed to Step 3
- **WARN (exit 2)**: Warnings present (typically from RC0 gate) → Review, then proceed
- **FAIL (exit 1)**: Prerequisites not met → **STOP**. Fix issues before proceeding.

**What it checks:**
- **A) Git Status Clean**: No uncommitted changes (must commit or stash before release)
- **B) RC0 Gate Result**: Calls `rc0_gate.ps1` and propagates result
- **C) Required Documentation**: `docs/ARCHITECTURE.md`, `docs/REPO_LAYOUT.md`, `docs/runbooks/incident.md`
- **D) Contract Snapshots**: `ops/snapshots/routes.pazar.json`, `ops/snapshots/schema.pazar.sql`
- **E) VERSION File**: Present, non-empty, valid format (X.Y.Z or X.Y.Z-rcN)

**Remediation:**

**Git Status Not Clean:**
```powershell
# Option 1: Commit changes
git add .
git commit -m "chore: prepare for RC0 release"

# Option 2: Stash changes (if temporary)
git stash push -m "WIP: before RC0 release"
```

**Missing Documentation:**
- Ensure all required docs exist (see `docs/REPO_LAYOUT.md` for canonical locations)
- Update `docs/ARCHITECTURE.md` if architecture changed
- Update `docs/REPO_LAYOUT.md` if repo structure changed
- Ensure `docs/runbooks/incident.md` exists (from Incident Pack v1)

**Missing Snapshots:**
```powershell
# Generate routes snapshot
.\ops\routes_snapshot.ps1

# Generate schema snapshot
.\ops\schema_snapshot.ps1
```

**VERSION File Issues:**
- Ensure `VERSION` file exists at repo root
- Format: `X.Y.Z` (e.g., `0.1.0`) or `X.Y.Z-rcN` (e.g., `0.1.0-rc0`)
- See `docs/ops/VERSIONING.md` for versioning rules

---

### Step 3: Generate Release Bundle

**Purpose:** Create a portable evidence folder for RC0 release (proof + summary).

**Command:**
```powershell
.\ops\release_bundle.ps1
```

**Expected Output:**
```
=== RELEASE BUNDLE GENERATOR ===
Creating release bundle: _archive/releases/release-20260110-120000
[PASS] Bundle folder created
...
=== RELEASE BUNDLE COMPLETE ===
Bundle location: _archive/releases/release-20260110-120000
Files collected: 10
RELEASE_BUNDLE_PATH=_archive/releases/release-20260110-120000
```

**What it collects:**
- `meta.txt`: Git branch, commit, status
- `version.txt`: VERSION file contents
- `rc0_gate_output.txt`: Full RC0 gate output
- `release_check_output.txt`: Full release check output
- `ops_status_output.txt`: Full ops status dashboard output
- `incident_bundle_path.txt`: Path to last incident bundle (if any)
- `proof_*.md`: Selected proof documentation files

**Location:** `_archive/releases/release-YYYYMMDD-HHMMSS/`

**Usage:**
- Attach to release notes or PR
- Store as evidence for release validation
- Share with stakeholders for review

---

### Step 4: Tag and Release Notes (Manual)

**Purpose:** Create git tag and prepare release notes.

**Prerequisites:**
- Steps 1-3 completed successfully
- `VERSION` file contains target version
- `CHANGELOG.md` updated (move `[Unreleased]` to version section)

**Tag Creation:**
```bash
# Read version from VERSION file
VERSION=$(cat VERSION)

# Create annotated tag
git tag -a "v${VERSION}" -m "Release v${VERSION}"

# Push tag
git push origin "v${VERSION}"
```

**Or for PowerShell:**
```powershell
$version = Get-Content VERSION -Raw | ForEach-Object { $_.Trim() }
git tag -a "v$version" -m "Release v$version"
git push origin "v$version"
```

**Release Notes:**
- Update `CHANGELOG.md`: Move `[Unreleased]` entries to new version section
- Format: `## [X.Y.Z-rcN] - YYYY-MM-DD`
- Include key changes, fixes, and breaking changes (if any)

**Example:**
```markdown
## [Unreleased]

## [0.1.0-rc0] - 2026-01-10

### Added
- RC0 Release Pack v1: Release checklist enforcement and bundle generation
- RC0 Gate Pack v1: Single-command RC0 readiness check

### Changed
- Updated documentation structure

### Fixed
- Fixed issue X
```

---

## CI Workflow Integration

The `.github/workflows/release-check.yml` workflow automatically runs release checks on:
- **Push to main**: Automatic validation on every push
- **Manual dispatch**: Trigger via GitHub Actions UI

**Workflow Steps:**
1. Checkout code
2. Start core services (for RC0 gate checks)
3. Run `release_check.ps1`
4. Generate release bundle (on any result)
5. Upload release bundle as artifact (always)
6. Cleanup services

**Artifact:** `release-bundle` (retained for 30 days)

---

## Versioning Rules

See `docs/ops/VERSIONING.md` for detailed versioning policy.

**Quick Reference:**
- **RC0**: `0.1.0-rc0` (first release candidate)
- **RC1+**: `0.1.0-rc1`, `0.1.0-rc2`, etc. (subsequent candidates)
- **Final Release**: `0.1.0` (after RC validation)

**When to bump:**
- **Major (X.0.0)**: Breaking changes
- **Minor (0.X.0)**: New features (backward compatible)
- **Patch (0.0.X)**: Bug fixes, security patches
- **RC (X.Y.Z-rcN)**: Pre-release stabilization

---

## Troubleshooting

### RC0 Gate FAIL

**Symptom:** RC0 gate reports blocking failures.

**Remediation:**
1. Review RC0 gate output for specific failures
2. See `docs/runbooks/rc0_gate.md` for remediation guidance
3. Fix issues and re-run RC0 gate
4. Ensure all blocking checks PASS before proceeding

### Release Check FAIL - Git Status Not Clean

**Symptom:** Release check reports uncommitted changes.

**Remediation:**
```powershell
# Check what's changed
git status

# Commit changes (if ready)
git add .
git commit -m "chore: prepare for RC0 release"

# Or stash changes (if temporary)
git stash push -m "WIP: before RC0 release"
```

### Release Check FAIL - Missing Snapshots

**Symptom:** Contract snapshots not found.

**Remediation:**
```powershell
# Generate routes snapshot
.\ops\routes_snapshot.ps1

# Generate schema snapshot
.\ops\schema_snapshot.ps1

# Verify snapshots created
Test-Path ops\snapshots\routes.pazar.json
Test-Path ops\snapshots\schema.pazar.sql
```

### Release Check FAIL - Invalid VERSION Format

**Symptom:** VERSION file format invalid.

**Remediation:**
- Check `VERSION` file at repo root
- Format must be: `X.Y.Z` or `X.Y.Z-rcN`
- Examples: `0.1.0`, `0.1.0-rc0`, `1.2.3-rc1`
- Fix format and re-run release check

---

## Related Documentation

- `docs/ops/VERSIONING.md` - Versioning policy and tag discipline
- `docs/RELEASE_CHECKLIST.md` - Manual release checklist
- `docs/runbooks/rc0_gate.md` - RC0 gate runbook
- `ops/release_check.ps1` - Release check script implementation
- `ops/release_bundle.ps1` - Release bundle generator implementation
- `docs/RULES.md` - Rule 38: RC0 requires release_check PASS/WARN + bundle attached








