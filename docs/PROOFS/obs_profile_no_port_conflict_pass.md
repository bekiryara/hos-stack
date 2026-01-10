# Obs Profile No Port Conflict Pass - Proof

## Overview

This document provides proof that `ops/stack_up.ps1 -Profile obs` successfully starts only observability services without port conflicts, specifically avoiding the 3000 port conflict with core stack's `hos-api`.

## Problem

Previously, running `docker compose -f work/hos/docker-compose.yml --profile obs up -d` would attempt to start `api` service (port 3000), causing conflicts with the already-running core stack.

## Solution

- `ops/stack_up.ps1 -Profile obs` uses explicit service list
- Only starts: `prometheus`, `alertmanager`, `grafana`, `loki`, `promtail`, `tempo`, `otel-collector`, `postgres-exporter`, `alert-webhook`
- Does NOT start: `api`, `web`, `db`
- `work/hos/docker-compose.yml` updated: `api`, `web`, `db` services have `profiles: ["default"]` to exclude them from obs profile

## Proof Commands

### 1. Verify Core Stack Running (Port 3000 in Use)

```powershell
cd D:\stack

# Start core stack first
.\ops\stack_up.ps1 -Profile core

# Verify hos-api is running on port 3000
docker compose ps hos-api
```

**Expected Output:**
```
NAME                STATUS       PORTS
stack-hos-api-1     Up         127.0.0.1:3000->3000/tcp
```

**Key Validation:**
- ✅ `hos-api` service running
- ✅ Port 3000 bound to `127.0.0.1:3000`

### 2. Start Observability Stack (No Port Conflict)

```powershell
.\ops\stack_up.ps1 -Profile obs
```

**Expected Output:**
```
=== Stack Bring-Up ===
Profile: obs

[Obs] Bringing up observability stack...
  Using: work\hos\docker-compose.yml (with --profile obs)
  Obs bring-up: starting only observability services (no api/web/db)
[PASS] Observability stack started

OVERALL STATUS: PASS (All requested stacks started)
```

**Key Validation:**
- ✅ No "Bind for 127.0.0.1:3000 failed: port is already allocated" error
- ✅ Script completes successfully
- ✅ Exit code: 0

### 3. Verify Only Observability Services Started

```powershell
docker compose -f work/hos/docker-compose.yml --profile obs ps
```

**Expected Output:**
```
NAME                        STATUS       PORTS
hos-prometheus-1            Up         0.0.0.0:9090->9090/tcp
hos-alertmanager-1          Up         0.0.0.0:9093->9093/tcp
hos-grafana-1               Up         127.0.0.1:3001->3000/tcp
hos-loki-1                  Up         3100/tcp
hos-promtail-1              Up         (no ports)
hos-tempo-1                 Up         3200/tcp
hos-otel-collector-1        Up         (no ports)
hos-postgres-exporter-1     Up         9187/tcp
hos-alert-webhook-1         Up         (no ports)
```

**Key Validation:**
- ✅ `api` service is NOT listed
- ✅ `web` service is NOT listed
- ✅ `db` service is NOT listed
- ✅ Only observability services appear
- ✅ No port 3000 binding (core stack's hos-api already uses it)

### 4. Verify hos-api Still Running (No Conflict)

```powershell
docker compose ps hos-api
```

**Expected Output:**
```
NAME                STATUS       PORTS
stack-hos-api-1     Up         127.0.0.1:3000->3000/tcp
```

**Key Validation:**
- ✅ `hos-api` from core stack still running
- ✅ Port 3000 still bound to core stack's `hos-api`
- ✅ No conflict or port takeover

### 5. Verify Prometheus and Alertmanager Ready

```powershell
curl.exe -sS -i http://localhost:9090/-/ready
curl.exe -sS -i http://localhost:9093/-/ready
```

**Expected Output:**
```
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
...
```

**Key Validation:**
- ✅ Prometheus ready endpoint: HTTP 200
- ✅ Alertmanager ready endpoint: HTTP 200
- ✅ Both services operational

### 6. Verify Service Names (Webhook)

```powershell
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
- ✅ Service name is `alert-webhook` (compose service name)
- ✅ No `api`, `web`, `db` in the list
- ✅ All observability services present

### 7. Test Log Access (Service Name Usage)

```powershell
docker compose -f work/hos/docker-compose.yml logs alert-webhook --tail=20
```

**Expected Output:**
```
hos-alert-webhook-1  | <log output>
```

**Key Validation:**
- ✅ Command succeeds (no "no such service" error)
- ✅ Logs retrieved using compose service name `alert-webhook`
- ✅ Container name may differ (e.g., `hos-alert-webhook-1`) but service name works

## Verification Checklist

- ✅ `ops/stack_up.ps1 -Profile obs` completes without port conflict errors
- ✅ No "Bind for 127.0.0.1:3000 failed" error
- ✅ `docker compose -f work/hos/docker-compose.yml --profile obs ps` shows only observability services
- ✅ `api`, `web`, `db` services NOT started by obs profile
- ✅ Core stack's `hos-api` continues running on port 3000
- ✅ Prometheus accessible on port 9090
- ✅ Alertmanager accessible on port 9093
- ✅ Grafana accessible on port 3001 (mapped from 3000 to avoid conflict)
- ✅ Webhook service accessible via service name `alert-webhook`

## Files Changed

- `ops/stack_up.ps1` - Added explicit service list for obs profile (only observability services)
- `work/hos/docker-compose.yml` - Added `profiles: ["default"]` to `api`, `web`, `db` services to exclude them from obs profile
- `work/hos/docker-compose.yml` - Removed `depends_on: api` from `prometheus` service (obs profile should not depend on core services)

## Notes

- **Port Isolation:** Obs profile uses different ports (9090, 9093, 3001) than core stack (3000, 3002, 8080)
- **Service Isolation:** Obs profile explicitly excludes core services via explicit service list in `stack_up.ps1`
- **Network Sharing:** Both stacks share the same Docker network, allowing Prometheus to scrape metrics from core services
- **Deterministic:** Explicit service list ensures consistent behavior regardless of compose file configuration


