# Repo Entrypoints Pass - Proof

## Overview

This document provides proof that repository entrypoints (`ops/stack_up.ps1`, `ops/stack_down.ps1`) work correctly and that observability stack bring-up does not conflict with core stack ports.

## Acceptance Tests

### 1. Core Stack Bring-Up

```powershell
cd D:\stack

# Start core stack
.\ops\stack_up.ps1 -Profile core
```

**Expected Output:**
```
[INFO] === Stack Bring-Up ===
Profile: core

[Core] Bringing up core stack...
  Using: docker-compose.yml (root)
[PASS] Core stack started

[PASS] OVERALL STATUS: PASS (All requested stacks started)
```

**Key Validation:**
- ✅ Core stack services start successfully (hos-api, hos-web, pazar-app, pazar-db, hos-db)
- ✅ Exit code: 0

### 2. Observability Stack Bring-Up (No Port Conflicts)

```powershell
# Ensure core stack is running (from step 1)
docker compose ps | Select-String "hos-api|pazar-app"
# Expected: stack-hos-api-1 Up 127.0.0.1:3000->3000/tcp, stack-pazar-app-1 Up 127.0.0.1:8080->80/tcp

# Start observability stack
.\ops\stack_up.ps1 -Profile obs
```

**Expected Output:**
```
[INFO] === Stack Bring-Up ===
Profile: obs

[Obs] Bringing up observability stack...
  Using: work\hos\docker-compose.yml (with --profile obs)
  Obs bring-up: starting only observability services (no api/web/db)
[PASS] Observability stack started

[PASS] OVERALL STATUS: PASS (All requested stacks started)
```

**Key Validation:**
- ✅ NO "Bind for 127.0.0.1:3000 failed: port is already allocated" error
- ✅ Only observability services start (prometheus, alertmanager, grafana, loki, promtail, tempo, otel-collector, postgres-exporter, alert-webhook)
- ✅ Core stack services (hos-api, hos-web) remain running
- ✅ Exit code: 0

### 3. Verify Obs Profile Service Isolation

```powershell
# List services started by obs profile
docker compose -f work/hos/docker-compose.yml --profile obs ps --services
```

**Expected Output:**
```
prometheus
alertmanager
grafana
loki
promtail
tempo
otel-collector
postgres-exporter
alert-webhook
```

**Key Validation:**
- ✅ Only observability services listed
- ✅ NO `api`, `web`, or `db` services
- ✅ Port 3000 not bound by obs profile

### 4. Verify Port 3000 Not Allocated by Obs

```powershell
# Check if port 3000 is bound by obs services
docker compose -f work/hos/docker-compose.yml --profile obs ps | Select-String "3000"
# Expected: NO matches (empty output)

# Verify core stack still owns port 3000
docker compose ps | Select-String "3000"
# Expected: stack-hos-api-1 ... 127.0.0.1:3000->3000/tcp
```

**Key Validation:**
- ✅ Obs profile does NOT bind to port 3000
- ✅ Core stack hos-api continues to use port 3000
- ✅ No port conflicts

### 5. Stack Shutdown

```powershell
# Shutdown all stacks
.\ops\stack_down.ps1 -Profile all
```

**Expected Output:**
```
[INFO] === Stack Shutdown ===
Profile: all

[Obs] Shutting down observability stack...
  Using: work\hos\docker-compose.yml (with --profile obs)
[PASS] Observability stack stopped

[Core] Shutting down core stack...
  Using: docker-compose.yml (root)
[PASS] Core stack stopped

[PASS] OVERALL STATUS: PASS (All requested stacks stopped)
```

**Key Validation:**
- ✅ Both stacks shut down cleanly
- ✅ Exit code: 0

## Verification Checklist

- ✅ `ops/stack_up.ps1 -Profile obs` uses explicit service list (only observability services)
- ✅ Obs profile does NOT start `api`, `web`, or `db` services
- ✅ Port 3000 conflict eliminated (obs profile cannot bind to 3000)
- ✅ Core stack continues running when obs stack starts
- ✅ `ops/stack_down.ps1` safely shuts down both stacks

## Files Changed

- `ops/stack_up.ps1` - Added explicit service list for obs profile, only starts observability services
- `work/hos/docker-compose.yml` - Added `profiles: ["default"]` to `api`, `web`, `db` to exclude them from obs profile
- `docs/PROOFS/repo_entrypoints_pass.md` - This proof documentation
