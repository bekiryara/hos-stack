# Repository Layout Contract

This document defines the repository structure as an immutable contract. Any changes to the layout must be documented here and keep `ops/doctor.ps1` passing.

## Root Directory Structure

```
D:\stack/
├── VERSION                  # Semantic version (e.g., 0.1.0)
├── CHANGELOG.md            # Keep a Changelog format
├── README.md               # Entry point, links to docs/START_HERE.md
├── docker-compose.yml      # Main Docker Compose configuration
├── docker-compose.*.yml    # Additional override files (if any)
├── .github/                # GitHub configuration
│   ├── CODEOWNERS         # Code ownership rules
│   └── workflows/         # GitHub Actions workflows
├── ops/                    # Operations scripts
│   ├── verify.ps1         # Stack health verification
│   ├── triage.ps1         # Incident triage script
│   ├── conformance.ps1    # Architecture conformance check
│   ├── doctor.ps1         # Comprehensive repository health check
│   ├── routes_snapshot.ps1
│   ├── schema_snapshot.ps1
│   ├── snapshots/         # Contract snapshots
│   │   ├── routes.pazar.json
│   │   └── schema.pazar.sql
│   └── diffs/             # Diff reports (generated)
├── docs/                   # Documentation
│   ├── START_HERE.md      # Onboarding guide
│   ├── RULES.md           # Development rules
│   ├── ARCHITECTURE.md    # Architecture overview
│   ├── REPO_LAYOUT.md     # This file
│   ├── FOUNDING_SPEC.md   # Founding specification (canonical)
│   ├── CURRENT.md         # Current state (canonical)
│   ├── PROOFS/            # Proof documentation
│   │   └── cleanup_pass.md
│   └── runbooks/          # Operational runbooks
│       ├── incident.md
│       ├── observability.md
│       └── errors.md
├── work/                   # Local-only application code (NOT TRACKED)
│   ├── pazar/             # Pazar application
│   └── hos/               # H-OS application
└── _archive/               # Archived files (allowed, but not for runtime)
    └── YYYYMMDD/
```

## Directory Definitions

### Root Files
- **VERSION**: Current semantic version (must be updated on release)
- **CHANGELOG.md**: All notable changes (Keep a Changelog format)
- **README.md**: Main entry point, must link to `docs/START_HERE.md`

### ops/
Operations scripts directory. All scripts must:
- Be Windows PowerShell compatible (`.ps1`)
- Exit with 0 on PASS, 1 on FAIL
- Provide clear PASS/FAIL/WARN output

### docs/
Documentation directory. Rules:
- **Single-source of truth**: No duplicate docs (e.g., no `CURRENT_v2.md`, no `FOUNDING_SPEC_backup.md`)
- **Canonical files only**: `FOUNDING_SPEC.md`, `CURRENT.md` (no versions, no backups)
- **Runbooks**: Operational procedures in `runbooks/`
- **Proofs**: Evidence and validation in `PROOFS/`

### work/
**IMPORTANT**: This directory is **local-only** and **NEVER TRACKED** in Git.
- Contains application code (`work/pazar/`, `work/hos/`)
- Volume-mounted into Docker containers for live code reload
- Should be in `.gitignore` (or explicitly excluded)

### _archive/
Archived files directory (allowed but should not be used for runtime):
- Format: `_archive/YYYYMMDD/category/`
- Examples: `_archive/20260108/cleanup_low/`, `_archive/20260108/cleanup_high/`
- **NOT for**: Runtime logs, secrets, or temporary files (use proper cleanup)

## Naming Rules

### Documentation Files
- ✅ **Allowed**: `FOUNDING_SPEC.md`, `CURRENT.md`, `START_HERE.md`
- ❌ **Forbidden**: `CURRENT_v2.md`, `FOUNDING_SPEC_backup.md`, `README_v1.md`
- **Rule**: Use canonical filenames only. For versioning, use Git history or CHANGELOG.md.

### Operations Scripts
- ✅ **Format**: `*.ps1` (PowerShell scripts)
- ✅ **Naming**: `verify.ps1`, `triage.ps1`, `doctor.ps1` (lowercase, descriptive)
- ❌ **Forbidden**: `verify_v2.ps1`, `triage_backup.ps1`

### Snapshot Files
- ✅ **Format**: `ops/snapshots/{type}.{world}.{extension}`
- ✅ **Examples**: `routes.pazar.json`, `schema.pazar.sql`
- ❌ **Forbidden**: `routes_backup.json`, `routes_v2.pazar.json`

## Do's and Don'ts

### ✅ DO
1. **Keep root clean**: Only essential files (VERSION, CHANGELOG.md, README.md, docker-compose.yml)
2. **Use canonical docs**: Reference `FOUNDING_SPEC.md`, `CURRENT.md` (no duplicates)
3. **Archive properly**: Move old files to `_archive/YYYYMMDD/category/`
4. **Track snapshots**: Keep `ops/snapshots/` files in Git for contract validation
5. **Update layouts**: When changing structure, update `docs/REPO_LAYOUT.md` and keep `ops/doctor.ps1` passing
6. **Use ops scripts**: Run `ops/doctor.ps1` before commits to verify repo health
7. **Follow naming rules**: Use lowercase, descriptive names for scripts and docs
8. **Document changes**: Update `CHANGELOG.md` and relevant docs when making structural changes
9. **Keep work/ local**: Never commit `work/` directory (use volume mounts for Docker)
10. **Maintain proofs**: Update `docs/PROOFS/cleanup_pass.md` for significant changes

### ❌ DON'T
1. **No root artifacts**: Don't commit `.zip`, `.rar`, `.bak`, `.tmp` files in root
2. **No duplicate docs**: Don't create `CURRENT_v2.md` or `FOUNDING_SPEC_backup.md`
3. **No tracked secrets**: Don't commit `secrets/*.txt`, `.env` files
4. **No tracked logs**: Don't commit `storage/logs/*.log` files
5. **No runtime in _archive**: Don't put runtime logs or secrets in `_archive/`
6. **No versioned filenames**: Don't use `_v2`, `_backup`, `_old` suffixes
7. **No breaking layout**: Don't change root structure without updating `docs/REPO_LAYOUT.md`
8. **No untracked snapshots**: Don't add snapshot files without updating `ops/doctor.ps1` if needed
9. **No work/ commits**: Don't accidentally commit `work/` directory
10. **No inconsistent naming**: Don't mix `snake_case` and `kebab-case` or use `camelCase` for files

## Validation

Repository layout compliance is validated by:
- **ops/doctor.ps1**: Checks for forbidden root artifacts, tracked secrets, required snapshots
- **.github/workflows/repo-guard.yml**: CI gate for root artifacts, tracked logs/secrets
- **Manual review**: CODEOWNERS require review for structural changes

## Related Documentation

- [Architecture](./ARCHITECTURE.md) - System architecture and services
- [Rules](./RULES.md) - Development rules (includes layout change rule)
- [Start Here](./START_HERE.md) - Onboarding guide

