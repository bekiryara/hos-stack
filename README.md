# Stack (H-OS + Pazar)

This repository runs **H-OS** (universe governance) and **Pazar** (first commerce world) services together in a standardized workspace.

## 🚀 Quick Start (2 Commands)

**New to this repo?** Start here: [`docs/ONBOARDING.md`](docs/ONBOARDING.md)

```powershell
# 1. Start the stack
docker compose up -d --build

# 2. Verify everything works
.\ops\verify.ps1
```

That's it! The stack should be running.

## What is This Repo?

This is a **RELEASE-GRADE BASELINE CORE v1** repository that combines:
- **H-OS**: Universe governance system (API + Web UI)
- **Pazar**: First commerce world (Laravel application)

**Baseline is FROZEN** - see [`docs/DECISIONS.md`](docs/DECISIONS.md) for what can and cannot be changed.

## Health Checks

Run these commands to verify the stack is healthy:

- **Full verification**: `.\ops\verify.ps1` (container status, health endpoints, filesystem)
- **Baseline status**: `.\ops\baseline_status.ps1` (minimum working state)
- **Conformance**: `.\ops\conformance.ps1` (repository conformance checks)
- **Daily snapshot**: `.\ops\daily_snapshot.ps1` (capture evidence for troubleshooting)

All commands return exit code `0` on success, `1` on failure.

## Public Repository Rules

**⚠️ IMPORTANT:** This is a public repository. Follow these rules:

- **Never commit secrets:** Never commit `.env` files, API keys, passwords, or tokens
- **Run checks before pushing:** Run `.\ops\public_ready_check.ps1` before pushing
- **Use environment variables:** Use `.env` files (not tracked) for local configuration
- **Test values only:** Test tokens/keys in code must be clearly marked as test-only

**Before pushing:**
```powershell
.\ops\public_ready_check.ps1
```

**If secrets are detected:**
- See `REMEDIATION_SECRETS.md` for remediation steps
- See `docs/runbooks/repo_public_release.md` for detailed guide

## Baseline is Frozen

**⚠️ IMPORTANT:** The baseline is frozen. These items **CANNOT** be changed without explicit decision:

- Docker Compose topology (service names, ports: 3000, 3002, 8080)
- Health endpoints (`/v1/health`, `/up`)
- Verification script exit codes

**What CAN change:**
- Business logic (application code, routes, controllers)
- Database schema (with proper migrations)
- Optional services (observability stack)
- Documentation (always welcome!)

See [`docs/DECISIONS.md`](docs/DECISIONS.md) for the complete frozen baseline definition.

## Documentation

### Entry Points
- **Onboarding**: [`docs/ONBOARDING.md`](docs/ONBOARDING.md) - Quick start for newcomers
- **Current State**: [`docs/CURRENT.md`](docs/CURRENT.md) - Single source of truth (stack, ports, services)
- **Decisions**: [`docs/DECISIONS.md`](docs/DECISIONS.md) - Baseline definition + frozen items
- **What We Did**: [`docs/NE_YAPTIK.md`](docs/NE_YAPTIK.md) - Summary of repository hardening

### Daily Operations
- **Daily Ops**: [`docs/runbooks/daily_ops.md`](docs/runbooks/daily_ops.md) - Daily snapshot runbook
- **Repo Hygiene**: [`docs/runbooks/repo_hygiene.md`](docs/runbooks/repo_hygiene.md) - File management rules

### Contributing
- **Contributing**: [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) - Commit rules, PR conventions, CHANGELOG discipline
- **Commit Rules**: [`docs/COMMIT_RULES.md`](docs/COMMIT_RULES.md) - Commit message format

## Repository Structure

```
.
├── docker-compose.yml          # CANONICAL compose (hos + pazar)
├── ops/                        # Operations scripts
│   ├── verify.ps1             # Full health check
│   ├── baseline_status.ps1    # Baseline status check
│   ├── conformance.ps1        # Conformance checks
│   ├── daily_snapshot.ps1     # Daily evidence capture
│   └── ci_guard.ps1          # CI drift guard
├── docs/                       # Documentation
│   ├── CURRENT.md             # Single source of truth
│   ├── ONBOARDING.md          # Quick start guide
│   ├── DECISIONS.md           # Baseline decisions
│   └── PROOFS/                # Proof documents
├── work/
│   ├── hos/                   # H-OS service
│   └── pazar/                 # Pazar service
├── _graveyard/                # Quarantined code (not deleted)
└── _archive/                  # Archives (daily snapshots, releases)
```

## Services & Ports

- **H-OS API**: `http://localhost:3000` (health: `/v1/health`)
- **H-OS Web**: `http://localhost:3002`
- **Pazar App**: `http://localhost:8080` (health: `/up`)

See [`docs/CURRENT.md`](docs/CURRENT.md) for complete service details.

## Secrets & Configuration

### H-OS Secrets
- Location: `work/hos/secrets/`
- **IMPORTANT**: Real secret values should NOT be tracked in git (local use only)

### Pazar .env
- Example: `work/pazar/docs/env.example`
- **IMPORTANT**: `.env` file should NOT be tracked in git (local use only)

See [`SECURITY.md`](SECURITY.md) for security policy.

## Development Rules

**Before starting new work:**
1. Run `.\ops\verify.ps1` → Must PASS
2. Run `.\ops\conformance.ps1` → Must PASS
3. If either fails, fix issues before proceeding

**No PASS, No Next Step** - This ensures baseline remains stable.

## Releases

- **Version**: See `VERSION` file
- **Changelog**: [`CHANGELOG.md`](CHANGELOG.md) (Keep a Changelog format)
- **Baseline Releases**: [`docs/RELEASES/BASELINE.md`](docs/RELEASES/BASELINE.md)

## Getting Help

- **Stack issues**: Run `.\ops\triage.ps1`
- **Full status**: Run `.\ops\baseline_status.ps1` (faster) or `.\ops\doctor.ps1` (comprehensive)
- **Documentation**: Start with [`docs/CURRENT.md`](docs/CURRENT.md)

## License

See [`LICENSE`](LICENSE) file for license information.

## Security

See [`SECURITY.md`](SECURITY.md) for security policy and vulnerability disclosure.
