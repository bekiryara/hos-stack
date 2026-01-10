# Observability Status Runbook

## Overview

This runbook explains how to bring up and manage the observability stack (Prometheus, Alertmanager, Grafana, Loki, Promtail, Tempo, OpenTelemetry Collector) separately from the core stack to avoid port conflicts.

## Canonical Stack Management

### Recommended Usage

**Core Stack (Pazar + H-OS):**
```powershell
.\ops\stack_up.ps1 -Profile core
```

**Observability Stack:**
```powershell
.\ops\stack_up.ps1 -Profile obs
```

**Both Stacks:**
```powershell
.\ops\stack_up.ps1 -Profile all
```

**Shutdown:**
```powershell
.\ops\stack_down.ps1 -Profile obs  # Only observability
.\ops\stack_down.ps1 -Profile core # Only core
.\ops\stack_down.ps1               # All (default)
```

## Important Rule: Obs Profile Does NOT Include Core Services

The observability profile (`--profile obs`) is **isolated** and does NOT include core services:
- ❌ `api` (port 3000) - NOT started by obs profile
- ❌ `web` (port 3002) - NOT started by obs profile  
- ❌ `db` - NOT started by obs profile

The obs profile only starts these services:
- ✅ `prometheus` (port 9090)
- ✅ `alertmanager` (port 9093)
- ✅ `grafana` (port 3001)
- ✅ `loki` (port 3100)
- ✅ `promtail`
- ✅ `tempo` (port 3200)
- ✅ `otel-collector`
- ✅ `postgres-exporter` (port 9187)
- ✅ `alert-webhook` (internal)

## Port Mappings

- **Core Stack:**
  - H-OS API: `127.0.0.1:3000:3000`
  - H-OS Web: `127.0.0.1:3002:80`
  - Pazar App: `127.0.0.1:8080:80`

- **Observability Stack:**
  - Prometheus: `127.0.0.1:9090:9090`
  - Alertmanager: `127.0.0.1:9093:9093`
  - Grafana: `127.0.0.1:3001:3000` (mapped to 3001 to avoid conflict with H-OS API)

## Troubleshooting

### Port Conflict on 3000

**Symptom:** `Bind for 127.0.0.1:3000 failed: port is already allocated`

**Cause:** Obs profile tried to start `api` service which conflicts with core stack's `hos-api`.

**Fix:**
1. Use `ops/stack_up.ps1 -Profile obs` instead of manual compose commands
2. The script explicitly lists only observability services
3. Verify: `docker compose -f work/hos/docker-compose.yml --profile obs ps` should NOT show `api` or `web`

### Service Not Starting

**Symptom:** Prometheus/Alertmanager not starting

**Check:**
```powershell
docker compose -f work/hos/docker-compose.yml --profile obs ps
```

**Verify services:**
- Only observability services should be listed
- `api`, `web`, `db` should NOT appear

### Webhook Service Name

**Canonical service name:** `alert-webhook` (compose service name, not container name)

**Check logs:**
```powershell
docker compose -f work/hos/docker-compose.yml logs alert-webhook
```

**Note:** Container name may be `hos-alert-webhook-1` or similar, but always use the compose service name `alert-webhook` in commands.

## Network Isolation

The observability stack uses the same Docker network as the core stack (via external network `stack_network` mapped to `stack_default`), allowing Prometheus to scrape metrics from:
- `hos-api:3000` (from root compose)
- `pazar-app:80` (from root compose)

## Manual Commands (Debugging Only)

While `ops/stack_up.ps1` is the canonical entry point, manual commands for debugging:

```powershell
# Start only observability services
docker compose -f work/hos/docker-compose.yml --profile obs up -d prometheus alertmanager grafana loki promtail tempo otel-collector postgres-exporter alert-webhook

# Check status
docker compose -f work/hos/docker-compose.yml --profile obs ps

# View logs
docker compose -f work/hos/docker-compose.yml --profile obs logs prometheus
docker compose -f work/hos/docker-compose.yml --profile obs logs alert-webhook
```

**Important:** These manual commands are for debugging only. Use `ops/stack_up.ps1` for normal operations.


