# Alerts Pipeline Runbook

## Overview

This runbook documents how to verify the end-to-end alert pipeline: Prometheus -> Alertmanager -> Webhook. The pipeline can be proven deterministically using `ops/alert_pipeline_proof.ps1`.

## Architecture

```
Prometheus (alerts.yml) 
  -> Alertmanager (alertmanager.yml) 
    -> Webhook (alert-webhook:8080)
      -> /last endpoint (GET /last returns last received alert payload)
```

## Alert Pipeline Proof

### Running the Proof

```powershell
.\ops\alert_pipeline_proof.ps1
```

**Expected Output (PASS):**
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

**Exit Codes:**
- `0` = PASS (alert received in webhook, payload matches)
- `2` = WARN (observability services not running, obs profile not started)
- `1` = FAIL (alert not received within timeout, or payload mismatch)

### How It Works

1. **Alertmanager Ready Check**: Verifies Alertmanager is accessible at `http://localhost:9093/-/ready`
2. **Webhook Reachable Check**: Verifies webhook is accessible via container exec
3. **Alert POST**: Sends a test alert to Alertmanager API (`POST /api/v2/alerts`) with:
   - `alertname=ManualTestCritical`
   - `severity=critical`
   - `service=pazar`
4. **Polling**: Polls webhook `/last` endpoint for up to 60 seconds (default) to check if alert was received
5. **Payload Match**: Verifies the received alert matches the sent alert (alertname, severity, service)

### Webhook /last Endpoint

The `alert-webhook` service exposes a `/last` endpoint that returns the last received alert payload:

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

**Important Notes:**
- The endpoint returns the last POST payload received by the webhook (Alertmanager sends alerts as an array)
- The payload is stored in-memory (single container instance, not persisted across restarts)
- The endpoint does NOT expose secrets or sensitive data
- If no alerts have been received, `last` will be `null`

### Troubleshooting

#### Alert Not Received (FAIL)

**Check Alertmanager logs:**
```powershell
docker compose -f work/hos/docker-compose.yml logs alertmanager | Select-String "webhook"
```

**Check webhook logs:**
```powershell
docker compose -f work/hos/docker-compose.yml logs alert-webhook
```

**Manually check webhook /last:**
```powershell
$containerName = (docker compose -f work/hos/docker-compose.yml ps alert-webhook --format "{{.Names}}")
docker exec $containerName python -c "import urllib.request, json; print(json.dumps(json.loads(urllib.request.urlopen('http://localhost:8080/last').read().decode('utf-8')), indent=2))"
```

**Common Issues:**
- Alertmanager not routing to webhook (check `alertmanager.yml` receiver configuration)
- Webhook container not running (check `docker compose -f work/hos/docker-compose.yml ps alert-webhook`)
- Network connectivity issues between Alertmanager and webhook (check service names match)

#### Observability Services Not Running (WARN)

If obs profile is not started:
```powershell
.\ops\stack_up.ps1 -Profile obs
```

Then re-run the proof:
```powershell
.\ops\alert_pipeline_proof.ps1
```

## Related

- `ops/alert_pipeline_proof.ps1` - Automated alert pipeline proof script
- `docs/PROOFS/alert_pipeline_pass.md` - Proof documentation with acceptance tests
- `work/hos/services/observability/alert-webhook/server.py` - Webhook implementation with `/last` endpoint










