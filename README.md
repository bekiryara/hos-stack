# Stack (H-OS + Pazar)

This repository runs **H-OS** (universe governance) and **Pazar** (first commerce world) services together.

## Quick Start (2 Commands)

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

**Baseline is FROZEN** - do not change ports, compose topology, or health endpoints without an explicit decision.

## Health Checks

Run these commands to verify the stack is healthy:

- **Full verification**: `.\ops\verify.ps1` (container status, health endpoints, filesystem)
- **Baseline status**: `.\ops\baseline_status.ps1` (minimum working state)
- **Conformance**: `.\ops\conformance.ps1` (repository conformance checks)
- **Daily snapshot**: `.\ops\daily_snapshot.ps1` (capture evidence for troubleshooting)

All commands return exit code `0` on success, `1` on failure.

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

## Documentation (V1)

- **Discipline**: [`docs/DEV_DISCIPLINE.md`](docs/DEV_DISCIPLINE.md)
- **New Chat Protocol**: [`docs/NEW_CHAT_PROTOCOL.md`](docs/NEW_CHAT_PROTOCOL.md)

All other files under `docs/` are considered **historical** (kept for traceability, not a source of truth).

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
├── docs/                       # Documentation (V1: see DEV_DISCIPLINE + NEW_CHAT_PROTOCOL)
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

Service details are intentionally kept minimal in V1. If something is unclear, use `docker compose ps` and the health endpoints.

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
- **Baseline Releases**: See `VERSION` + `CHANGELOG.md`

## Getting Help

- **Stack issues**: Run `.\ops\triage.ps1`
- **Full status**: Run `.\ops\baseline_status.ps1` (faster) or `.\ops\doctor.ps1` (comprehensive)
- **Documentation**: Start with `docs/DEV_DISCIPLINE.md`

## License

See [`LICENSE`](LICENSE) file for license information.

## Security

See [`SECURITY.md`](SECURITY.md) for security policy and vulnerability disclosure.
