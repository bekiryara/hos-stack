# ONBOARDING - Quick Start for Newcomers

> ⚠️ **IMPORTANT**
>
> All technical conversations and new agents MUST start by following:
> [`docs/NEW_CHAT_PROTOCOL.md`](NEW_CHAT_PROTOCOL.md)

**Target Audience:** New developers joining the project  
**Goal:** Get the stack running with 2 commands

## Prerequisites

1. **Docker Desktop** (Windows/Mac) or Docker Engine + Docker Compose (Linux)
   - Docker version 20.10+
   - Docker Compose version 2.0+

2. **PowerShell** (Windows) or PowerShell Core (Mac/Linux)
   - Windows: PowerShell 5.1+ (included with Windows)
   - Mac/Linux: Install PowerShell 7+ from https://github.com/PowerShell/PowerShell

3. **Git** (for cloning the repository)

## Quick Start (2 Commands)

### Step 1: Start the Stack

```powershell
docker compose up -d --build
```

This command:
- Builds all Docker images
- Starts all required services (hos-db, hos-api, hos-web, pazar-db, pazar-app)
- Runs in detached mode (`-d`)

**Expected:** Containers start and show "Up" status.

### Step 2: Verify Everything Works

```powershell
.\ops\verify.ps1
```

This command checks:
- All containers are running
- H-OS API responds at `http://localhost:3000/v1/health`
- Pazar App responds at `http://localhost:8080/up`
- Filesystem permissions are correct

**Expected:** "VERIFICATION PASS" message.

## If It Fails: Run Triage

If `verify.ps1` fails, run the triage script:

```powershell
.\ops\triage.ps1
```

This will:
- Check Docker status
- Show container logs
- Identify common issues
- Provide remediation hints

**Common Issues:**

1. **Port already in use**: Stop other services using ports 3000, 3002, or 8080
2. **Docker not running**: Start Docker Desktop
3. **Build failed**: Check Docker logs for missing files or build errors
4. **Health checks timeout**: Wait 30 seconds and try again (services may still be starting)

## Daily Evidence Capture

**After verification passes, capture evidence:**

```powershell
.\ops\daily_snapshot.ps1
```

This creates a snapshot in `_archive/daily/YYYYMMDD-HHmmss/` containing:
- Git status and commit hash
- Container status (`docker compose ps`)
- Recent logs (last 200 lines)
- Health check results

**When to run:**
- Daily (before end of day)
- Before important changes
- After fixing issues
- Before PR submission

**Evidence location:** `_archive/daily/YYYYMMDD-HHmmss/`

## Next Steps

Once the stack is running:

- **H-OS API**: `http://localhost:3000/v1/health`
- **H-OS Web**: `http://localhost:3002`
- **Pazar App**: `http://localhost:8080`

Read `docs/CURRENT.md` for the complete stack overview.

## Getting Help

- **Stack issues**: Run `.\ops\triage.ps1`
- **Full status**: Run `.\ops\baseline_status.ps1` (faster) or `.\ops\doctor.ps1` (comprehensive)
- **Documentation**: Start with `docs/CURRENT.md`

## Publishing Changes

**Single publish path:** All changes to main branch must go through `.\ops\ship_main.ps1` (runs gates, then push). See `docs/DEV_DISCIPLINE.md` for details.


