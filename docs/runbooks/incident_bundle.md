# Incident Bundle Generator

## Overview

The incident bundle generator collects system state, logs, and configuration snapshots to create a comprehensive evidence package for incident investigation and post-mortem analysis.

## How to Run

```powershell
.\ops\incident_bundle.ps1
```

The script creates a timestamped folder and collects evidence automatically.

## What It Collects

The bundle includes the following files:

1. **meta.txt** - Git metadata (branch, commit hash, status)
2. **compose_ps.txt** - Docker Compose services status (`docker compose ps`)
3. **hos_health.txt** - H-OS health endpoint response (`/v1/health`)
4. **pazar_up.txt** - Pazar up endpoint response (`/up`) with headers
5. **pazar_routes_snapshot.txt** - Routes snapshot (if exists)
6. **pazar_schema_snapshot.txt** - Database schema snapshot (if exists)
7. **version.txt** - Current version from `VERSION` file
8. **changelog_unreleased.txt** - Unreleased changelog entries
9. **logs_pazar_app.txt** - Last 500 lines of Pazar app logs
10. **logs_hos_api.txt** - Last 500 lines of H-OS API logs
11. **incident_note.md** - Template for incident notes (to be filled in)

## Where It Stores

Bundles are stored in:
```
_archive/incidents/incident-YYYYMMDD-HHMMSS/
```

Example:
```
_archive/incidents/incident-20260108-143022/
```

**Important**: Bundle folders are **not tracked in Git** (they're in `_archive/` which may be gitignored). They are for local collection and manual attachment to issues.

## Usage Workflow

### During an Incident

1. **Run the bundle generator**:
   ```powershell
   .\ops\incident_bundle.ps1
   ```

2. **Note the bundle location** (printed at the end)

3. **Fill in incident_note.md** with:
   - What happened
   - When (start/detection/resolution times)
   - Request ID(s) if applicable
   - Steps taken
   - Current status

4. **Continue investigation** using `ops/triage.ps1` if needed

### After Resolution

1. **Complete incident_note.md** with resolution details

2. **Attach bundle to issue/PR**:
   - Option A: Zip the bundle folder and attach to issue
   - Option B: Reference the bundle path in issue description
   - Option C: For GitHub issues, paste key log excerpts and reference bundle location

3. **Update incident runbook** if new patterns discovered

## Bundle Structure Example

```
_archive/incidents/incident-20260108-143022/
├── meta.txt
├── compose_ps.txt
├── hos_health.txt
├── pazar_up.txt
├── pazar_routes_snapshot.txt
├── pazar_schema_snapshot.txt
├── version.txt
├── changelog_unreleased.txt
├── logs_pazar_app.txt
├── logs_hos_api.txt
└── incident_note.md
```

## When to Generate a Bundle

Generate a bundle when:
- **SEV1/SEV2 incidents**: Always generate at detection time
- **Service outages**: Generate when service becomes unavailable
- **Error spikes**: Generate when error rates increase significantly
- **Before major changes**: Generate baseline before risky deployments
- **After incidents**: Generate post-resolution for comparison

## Best Practices

1. **Generate early**: Run the bundle generator as soon as an incident is detected
2. **Generate often**: Generate multiple bundles during long-running incidents (hourly or after major state changes)
3. **Fill in notes**: Complete `incident_note.md` while details are fresh
4. **Don't delete**: Keep bundles for post-mortem analysis (they're in `_archive/`)
5. **Reference in issues**: Always include bundle path or key excerpts in incident reports

## Related Documentation

- [Incident Runbook](./incident.md) - Incident response procedures
- [Observability Runbook](./observability.md) - Request ID tracing
- [Errors Runbook](./errors.md) - Error code reference

