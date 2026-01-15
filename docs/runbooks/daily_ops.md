# Daily Operations Runbook

## Purpose

Capture daily evidence snapshots of the stack state for:
- Troubleshooting historical issues
- Tracking changes over time
- Compliance and audit trails

## Daily Command

Run this command once per day (or as needed):

```powershell
.\ops\daily_snapshot.ps1
```

## What It Captures

The snapshot captures:

1. **Git Status**: `git status --short` (tracked changes)
2. **Git Commit**: `git rev-parse HEAD` (current commit hash)
3. **Docker Compose Status**: `docker compose ps` (container status)
4. **Container Logs**: Last 200 lines from:
   - hos-api
   - hos-db
   - hos-web
   - pazar-app
   - pazar-db
5. **Health Checks**:
   - H-OS: `http://localhost:3000/v1/health`
   - Pazar: `http://localhost:8080/up`
6. **Ops Status**: Output of `ops\ops_status.ps1` (if available)

## Snapshot Location

Snapshots are stored in:
```
_archive/daily/YYYYMMDD-HHmmss/
```

Example:
```
_archive/daily/20260114-143022/
├── git_status.txt
├── git_commit.txt
├── compose_ps.txt
├── logs_hos-api.txt
├── logs_hos-db.txt
├── logs_hos-web.txt
├── logs_pazar-app.txt
├── logs_pazar-db.txt
├── health_hos.txt
├── health_pazar.txt
└── ops_status.txt
```

## Quiet Mode

For automation or scripts, use quiet mode:

```powershell
.\ops\daily_snapshot.ps1 -Quiet
```

This suppresses progress messages and only outputs:
```
SNAPSHOT_OK path=_archive/daily/20260114-143022
```

## Retention

Snapshots are stored in `_archive/daily/` which is excluded from git (see `.gitignore`).  
Manual cleanup is recommended periodically to manage disk space.

## Troubleshooting

**If snapshot fails:**
1. Check Docker is running: `docker compose ps`
2. Check permissions: Ensure write access to `_archive/daily/`
3. Check disk space: Ensure sufficient space for logs

**If health checks fail:**
- Snapshot still succeeds (errors are captured in health files)
- Review `health_hos.txt` and `health_pazar.txt` for details


