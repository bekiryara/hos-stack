# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Architecture conformance gate: `ops/conformance.ps1` and `.github/workflows/conformance.yml` for automated architecture rule validation (world registry drift, forbidden artifacts, disabled-world code policy, canonical docs, secrets safety)
- Contract gate via route snapshot: `ops/routes_snapshot.ps1`, `ops/snapshots/routes.pazar.json`, and `.github/workflows/contracts.yml` for API contract validation (route signature comparison, diff generation on change)
- DB contract gate via schema snapshot: `ops/schema_snapshot.ps1`, `ops/snapshots/schema.pazar.sql`, and `.github/workflows/db-contracts.yml` for database schema validation (Postgres schema export, normalization, diff generation on change)
- Observability pack v1: Request ID middleware with structured logging context (service, route, method, request_id, tenant_id, user_id, world), X-Request-Id header propagation to H-OS API calls, request_id in outbox event payload, and observability runbook
- Error contract pack v1: Standard error envelope in global exception handler ({ ok:false, error_code, message, request_id, details? }), error code mapping (VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, INTERNAL_ERROR), structured error logging (event, error_code, request_id, route, method, world, user_id, exception_class), and error runbook
- Error contract CI gate: `.github/workflows/error-contract.yml` for automated validation of error response envelope format (422 VALIDATION_ERROR with details.fields, 404 NOT_FOUND with request_id)
- Incident pack v1: `docs/runbooks/incident.md` runbook with SEV definitions, triage checklist, request_id workflow, and CI gate troubleshooting
- Triage script: `ops/triage.ps1` for single-command health checks and log inspection

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

