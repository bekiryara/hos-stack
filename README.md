# Stack (H-OS + Pazar)

This repository runs **H-OS** (universe governance) and **Pazar** (first commerce world) services together.

## Quick Start (2 Commands)

```powershell
# 1. Start the stack
docker compose up -d --build

# 2. Verify everything works
.\ops\ops.ps1 verify
```

That's it! The stack should be running.

## What is This Repo?

This is a **RELEASE-GRADE BASELINE CORE v1** repository that combines:
- **H-OS**: Universe governance system (API + Web UI)
- **Pazar**: First commerce world (Laravel application)

**Baseline is FROZEN** - do not change ports, compose topology, or health endpoints without an explicit decision.

## Health Checks

Run these commands to verify the stack is healthy:

- **Full verification**: `.\ops\ops.ps1 verify` (container status, health endpoints, filesystem posture)
- **Baseline status**: `.\ops\ops.ps1 baseline-status` (minimum working state)
- **Conformance**: `.\ops\ops.ps1 conformance` (repo rules/drift checks)
- **Daily snapshot**: `.\ops\ops.ps1 daily-snapshot` (capture evidence for troubleshooting)
- **Unified dashboard**: `.\ops\ops.ps1 status -Ci` (deep status view)

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

Baseline definition/rules live in:
- [`docs/RELEASES/BASELINE.md`](docs/RELEASES/BASELINE.md)
- [`docs/SPEC.md`](docs/SPEC.md)
- [`docs/RULES.md`](docs/RULES.md)

## Documentation (V1)

Start here:
- **Start here**: [`docs/START_HERE.md`](docs/START_HERE.md)
- **Current truth**: [`docs/CURRENT.md`](docs/CURRENT.md)
- **Spec**: [`docs/SPEC.md`](docs/SPEC.md)
- **Rules / discipline**: [`docs/RULES.md`](docs/RULES.md), [`docs/DEV_DISCIPLINE.md`](docs/DEV_DISCIPLINE.md)
- **New chat protocol (agents)**: [`docs/NEW_CHAT_PROTOCOL.md`](docs/NEW_CHAT_PROTOCOL.md)

## Proof / Evidence (single file)

- Proof/evidence is recorded in one place: [`docs/PROOFS/PASS_LOG.md`](docs/PROOFS/PASS_LOG.md) (append-only).

## Repository Structure

```
.
├── docker-compose.yml          # CANONICAL compose (hos + pazar)
├── ops/                        # Operations (single entrypoint: ops.ps1)
│   ├── ops.ps1                # Dispatcher: verify/status/ship/... (preferred)
│   ├── ops_status.ps1         # Unified dashboard (called via ops.ps1 status)
│   ├── ops_run.ps1            # Daily runner (called via ops.ps1 run)
│   ├── _checks/               # Leaf check scripts (verify, conformance, contracts...)
│   ├── _tools/                # Utilities (secret scan, daily snapshot, etc.)
│   └── _legacy/               # Legacy pack (explicit, non-canonical tools)
├── docs/                       # Documentation (canonical: START_HERE/CURRENT/SPEC/RULES)
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
1. Run `.\ops\ops.ps1 verify` → Must PASS
2. Run `.\ops\ops.ps1 conformance` → Must PASS
3. If either fails, fix issues before proceeding

**No PASS, No Next Step** - This ensures baseline remains stable.

## Publish (single path)

To publish changes to `main` (runs gates, then pull --rebase and push):

```powershell
.\ops\ops.ps1 ship
```

## Releases

- **Version**: See `VERSION` file
- **Changelog**: [`CHANGELOG.md`](CHANGELOG.md) (Keep a Changelog format)
- **Baseline Releases**: See `VERSION` + `CHANGELOG.md`

## Getting Help

- **Stack issues**: Run `.\ops\ops.ps1 triage`
- **Full status**: Run `.\ops\ops.ps1 baseline-status` (fast) or `.\ops\ops.ps1 doctor` (deep)
- **Documentation**: Start with `docs/DEV_DISCIPLINE.md`

## License

See [`LICENSE`](LICENSE) file for license information.

## Security

See [`SECURITY.md`](SECURITY.md) for security policy and vulnerability disclosure.
