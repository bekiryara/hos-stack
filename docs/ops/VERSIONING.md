# Versioning Policy

## VERSION File Format

The root `VERSION` file is the single source of truth for the current release version.

**Format Rules:**
- Semantic versioning: `MAJOR.MINOR.PATCH`
- RC (Release Candidate) format: `MAJOR.MINOR.PATCH-rcN` (e.g., `0.1.0-rc0`, `0.1.0-rc1`)
- No leading zeros in version numbers
- Single line only (trailing newline optional)

**Examples:**
```
0.1.0
0.1.0-rc0
0.1.0-rc1
1.0.0
2.3.4-rc5
```

## RC Naming Convention

**RC (Release Candidate)** versions are used for pre-release validation:
- **Format**: `MAJOR.MINOR.PATCH-rcN` where `N` starts at 0
- **Purpose**: Stabilize a release before final tag
- **Increment**: `-rc0` → `-rc1` → `-rc2` → ... → final release (remove `-rcN` suffix)

**RC0**: First release candidate (initial stabilization)
**RC1+**: Subsequent candidates if issues found in RC0

## When to Bump Version

### Major Version (X.0.0)
- Breaking API changes
- Breaking database schema changes (migrations incompatible with previous version)
- Architectural changes that affect external integrations
- Significant breaking behavioral changes

### Minor Version (0.X.0)
- New features (backward compatible)
- New API endpoints (non-breaking)
- New capabilities (worlds, integrations, etc.)
- Deprecations (without removal)

### Patch Version (0.0.X)
- Bug fixes
- Security patches
- Performance improvements
- Documentation updates
- Non-breaking configuration changes

### RC Version (X.Y.Z-rcN)
- Pre-release stabilization
- All changes committed and validated
- RC0: Initial release candidate
- RC1+: If RC0 issues require fixes (bump RC number, keep base version)

## Version Bump Workflow

1. **Update VERSION file** (root/VERSION)
   - Bump appropriate component (MAJOR/MINOR/PATCH/RC)
   - Commit with message: `chore: bump version to X.Y.Z-rcN`

2. **Update CHANGELOG.md**
   - Move `[Unreleased]` entries to new version section
   - Format: `## [X.Y.Z-rcN] - YYYY-MM-DD`
   - Clear `[Unreleased]` section

3. **Run release checks**
   - `.\ops\release_check.ps1` must PASS
   - `.\ops\rc0_gate.ps1` must PASS/WARN (no blocking failures)

4. **Generate release bundle**
   - `.\ops\release_bundle.ps1` creates evidence folder

5. **Create git tag** (manual step)
   - `git tag -a vX.Y.Z-rcN -m "Release vX.Y.Z-rcN"`
   - `git push origin vX.Y.Z-rcN`

## Tag Discipline

**Important:** This document describes tag naming conventions only. No git operations are performed by automation scripts.

### Tag Format
- **Release tags**: `vX.Y.Z` or `vX.Y.Z-rcN`
- **Prefix**: Always use `v` prefix
- **Format**: Must match VERSION file exactly (with `v` prefix)

### Tag Creation (Manual)
```bash
# Read version from VERSION file
VERSION=$(cat VERSION)

# Create annotated tag
git tag -a "v${VERSION}" -m "Release v${VERSION}"

# Push tag
git push origin "v${VERSION}"
```

### Tag Naming Rules
- Use semantic versioning (matches VERSION file)
- Always include `v` prefix
- RC tags: `v0.1.0-rc0`, `v0.1.0-rc1`, etc.
- Final releases: `v0.1.0`, `v1.0.0`, etc.

### Tag Message Format
- **RC tags**: `Release vX.Y.Z-rcN` or more descriptive: `Release vX.Y.Z-rcN: RC0 stabilization`
- **Final releases**: `Release vX.Y.Z` or more descriptive: `Release vX.Y.Z: Production release`

## Version Validation

The `ops/release_check.ps1` script validates:
- VERSION file exists and is non-empty
- VERSION format matches semantic versioning pattern
- VERSION file contains only version string (no extra lines)

## Examples

### RC0 Release
```
VERSION: 0.1.0-rc0
Tag: v0.1.0-rc0
Message: "Release v0.1.0-rc0: RC0 stabilization"
```

### RC1 Release (if RC0 issues found)
```
VERSION: 0.1.0-rc1
Tag: v0.1.0-rc1
Message: "Release v0.1.0-rc1: RC1 with fixes"
```

### Final Release (after RC validation)
```
VERSION: 0.1.0
Tag: v0.1.0
Message: "Release v0.1.0: Production release"
```

## Related Documentation

- `docs/RELEASE_CHECKLIST.md` - Manual release checklist
- `docs/runbooks/release.md` - Release workflow runbook
- `ops/release_check.ps1` - Automated release validation
- `ops/release_bundle.ps1` - Release bundle generator








