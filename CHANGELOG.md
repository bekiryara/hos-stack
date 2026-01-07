# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Architecture conformance gate: `ops/conformance.ps1` and `.github/workflows/conformance.yml` for automated architecture rule validation (world registry drift, forbidden artifacts, disabled-world code policy, canonical docs, secrets safety)

### Changed
- Cleanup HIGH risk unused code: archived 3 empty World controller directories (`RealEstate/`, `Services/`, `Vehicles/`) to `_archive/20260108/cleanup_high/` (disabled worlds, no routes, no controllers)

## [0.1.0] - 2026-01-08

### Added
- Secrets lock: `.gitignore` entries for secrets and runtime artifacts
- Onboarding documentation: `docs/START_HERE.md` and `docs/RULES.md`
- Repo guard workflow: `.github/workflows/repo-guard.yml` (anti-drift protection)
- Smoke workflow: `.github/workflows/smoke.yml` (CI health checks)
- CODEOWNERS protection: `.github/CODEOWNERS` for critical paths
- Verification script: `ops/verify.ps1` for stack health checks
- Release discipline: `VERSION`, `CHANGELOG.md`, `docs/RELEASE_CHECKLIST.md`

### Fixed
- Laravel storage permissions: `docker-entrypoint.sh` fixes `www-data` ownership on container start
- OIDC login UX: form pre-fill and Docker session fallback

### Changed
- Cleanup LOW risk artifacts: moved to `_archive/20260108/cleanup_low/`
- Documentation structure: added proof tracking in `docs/PROOFS/cleanup_pass.md`

[Unreleased]: https://github.com/bekiryara/stack/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bekiryara/stack/releases/tag/v0.1.0

