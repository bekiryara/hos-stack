# Alert Pipeline Pass - Proof

## Overview

This document provides proof that the Alertmanager -> Webhook alert pipeline works end-to-end and can be verified deterministically using `ops/alert_pipeline_proof.ps1`.

## Architecture

```
Prometheus (alerts.yml) 
  -> Alertmanager (alertmanager.yml) 
    -> Webhook (alert-webhook:8080)
      -> /last endpoint (GET /last returns last received alert payload)
```

## Solution

1. **Webhook /last endpoint**: `alert-webhook` service exposes `GET /last` endpoint that returns the last received alert payload
2. **Alert pipeline proof script**: `ops/alert_pipeline_proof.ps1` verifies the pipeline end-to-end by:
   - Checking Alertmanager readiness
   - Checking webhook reachability
   - POSTing a test alert to Alertmanager
   - Polling webhook `/last` endpoint for up to 60 seconds
   - Verifying payload match (alertname, severity, service)

## Acceptance Tests

### 1. Start Observability Stack

```powershell
cd D:\stack

# Start observability stack (obs profile)
.\ops\stack_up.ps1 -Profile obs

# Wait for services to start
Start-Sleep -Seconds 10
```

**Expected:** Alertmanager, webhook, and other obs services start successfully.

### 2. Verify Alertmanager Ready

```powershell
curl.exe -sS -f -m 5 http://localhost:9093/-/ready
```

**Expected:** HTTP 200, exit code 0

### 3. Verify Webhook Reachable

```powershell
$containerName = (docker compose -f work/hos/docker-compose.yml ps alert-webhook --format "{{.Names}}")
docker exec $containerName python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health').read()"
```

**Expected:** No error, exit code 0

### 4. Verify Webhook /last Endpoint

```powershell
$containerName = (docker compose -f work/hos/docker-compose.yml ps alert-webhook --format "{{.Names}}")
docker exec $containerName python -c "import urllib.request, json; print(json.dumps(json.loads(urllib.request.urlopen('http://localhost:8080/last').read().decode('utf-8')), indent=2))"
```

**Expected Output (before any alerts):**
```json
{
  "ok": true,
  "count": 0,
  "last": null
}
```

**Key Validation:**
- Endpoint returns JSON with `ok`, `count`, and `last` fields
- `last` is `null` if no alerts have been received

### 5. Run Alert Pipeline Proof

```powershell
.\ops\alert_pipeline_proof.ps1
```

**Expected Output:**
```
=== Alert Pipeline Proof ===
Checking observability stack...
Checking Alertmanager readiness...
  Alertmanager is ready
Checking webhook reachability...
  Webhook is reachable
Sending test alert to Alertmanager...
  Alert posted successfully
Polling webhook /last endpoint (max 60s)...
  Alert received in webhook: alertname=ManualTestCritical, severity=critical, service=pazar

[PASS] OVERALL STATUS: PASS (Alert pipeline verified: Alertmanager -> Webhook)
```

**Key Validation:**
- All steps PASS
- Alert received in webhook within timeout
- Payload matches (alertname=ManualTestCritical, severity=critical, service=pazar)
- Exit code: 0

### 6. Verify Webhook /last After Alert

```powershell
$containerName = (docker compose -f work/hos/docker-compose.yml ps alert-webhook --format "{{.Names}}")
docker exec $containerName python -c "import urllib.request, json; print(json.dumps(json.loads(urllib.request.urlopen('http://localhost:8080/last').read().decode('utf-8')), indent=2))"
```

**Expected Output:**
```json
{
  "ok": true,
  "count": 1,
  "last": [
    {
      "labels": {
        "alertname": "ManualTestCritical",
        "severity": "critical",
        "service": "pazar"
      },
      "annotations": {
        "summary": "E2E pipeline test alert"
      },
      "startsAt": "2026-01-10T16:23:45.123Z",
      "endsAt": "2026-01-10T16:33:45.123Z"
    }
  ]
}
```

**Key Validation:**
- `count` is 1 (or greater if multiple alerts sent)
- `last` contains the alert payload array
- Alert labels match (alertname, severity, service)

### 7. Verify Obs Profile Not Running (WARN)

```powershell
# Stop obs stack
.\ops\stack_down.ps1 -Profile obs

# Run proof
.\ops\alert_pipeline_proof.ps1
```

**Expected Output:**
```
=== Alert Pipeline Proof ===
Checking observability stack...
[WARN] Alertmanager not running (obs profile may not be started) (SKIP)
```

**Key Validation:**
- WARN status (not FAIL)
- Exit code: 2
- Clear message indicating obs services not running

### 8. Verify Alertmanager Logs

```powershell
docker compose -f work/hos/docker-compose.yml logs alertmanager | Select-String "webhook" | Select-Object -Last 5
```

**Expected:** Log entries showing webhook delivery attempts/results.

### 9. Verify Webhook Logs

```powershell
docker compose -f work/hos/docker-compose.yml logs alert-webhook | Select-String "alert_webhook" | Select-Object -Last 5
```

**Expected:** JSON log entries with `event: "alert_webhook"` and payload.

## Verification Checklist

- ✅ Webhook `/last` endpoint returns JSON with `ok`, `count`, and `last` fields
- ✅ `/last` endpoint stores last received alert payload (Alertmanager format: array)
- ✅ `/last` endpoint does NOT expose secrets or sensitive data
- ✅ `ops/alert_pipeline_proof.ps1` exists and verifies pipeline end-to-end
- ✅ Alert pipeline proof checks Alertmanager readiness
- ✅ Alert pipeline proof checks webhook reachability
- ✅ Alert pipeline proof POSTs test alert to Alertmanager
- ✅ Alert pipeline proof polls `/last` endpoint and verifies payload match
- ✅ Alert pipeline proof returns WARN if obs services not running (not FAIL)
- ✅ Exit codes correct (0=PASS, 2=WARN, 1=FAIL)

## Files Changed

- `work/hos/services/observability/alert-webhook/server.py` - Added `/last` endpoint to store and return last received alert payload
- `ops/alert_pipeline_proof.ps1` - NEW - Alert pipeline proof script
- `docs/runbooks/alerts_pipeline.md` - NEW - Alert pipeline runbook
- `docs/PROOFS/alert_pipeline_pass.md` - This proof documentation










