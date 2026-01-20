param(
  [string]$AlertmanagerUrl = "http://localhost:9093"
)

$ErrorActionPreference = "Stop"

function Json($obj) { $obj | ConvertTo-Json -Compress -Depth 10 }

Write-Host "Alert test -> $AlertmanagerUrl"

# 1) Basic readiness
try {
  $ready = & curl.exe -sS "$AlertmanagerUrl/-/ready"
  Write-Host "ready: $(Json $ready)"
} catch {
  Write-Host "ERROR: alertmanager not ready: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

# 2) Send a test alert directly to Alertmanager API (no Prometheus dependency)
$now = [DateTime]::UtcNow
# Alertmanager expects a JSON *array* of alerts. In Windows PowerShell, single-item arrays can collapse to an object;
# force an array with the comma operator.
$alert = ,@{
  labels = @{
    alertname = "HOS_TestAlert"
    severity  = "critical"
    source    = "ops/alert_test.ps1"
  }
  annotations = @{
    summary = "H-OS test alert (safe)"
    description = "This is a synthetic alert sent directly to Alertmanager for end-to-end verification."
  }
  startsAt = $now.ToString("o")
  endsAt   = $now.AddMinutes(5).ToString("o")
}

try {
  $tmp = Join-Path $env:TEMP ("hos_alert_" + [Guid]::NewGuid().ToString("N") + ".json")
  $json = (Json $alert)
  # Safety: ensure JSON is an array even for single alert.
  if (-not $json.TrimStart().StartsWith("[")) { $json = "[" + $json + "]" }
  $enc = New-Object System.Text.UTF8Encoding($false) # UTF-8 without BOM
  [System.IO.File]::WriteAllText($tmp, $json, $enc)

  $resp = Join-Path $env:TEMP ("hos_alert_resp_" + [Guid]::NewGuid().ToString("N") + ".txt")
  $code = & curl.exe -sS -o $resp -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary ("@" + $tmp) "$AlertmanagerUrl/api/v2/alerts"
  if ($code -notmatch "^(200|201|202)$") {
    $body = ""
    try { $body = Get-Content -Raw $resp } catch {}
    throw "HTTP ${code}: $body"
  }
  Write-Host "sent: ok (HTTP $code)"
} catch {
  Write-Host "ERROR: failed to send test alert: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  try { if (Test-Path $tmp) { Remove-Item -Force $tmp } } catch {}
  try { if (Test-Path $resp) { Remove-Item -Force $resp } } catch {}
}

# 3) Proof: show webhook receiver logs (requires obs profile running)
Write-Host "waiting for webhook..."
Start-Sleep -Seconds 2

try {
  docker compose logs --tail 80 alert-webhook | Select-String -Pattern "HOS_TestAlert" -SimpleMatch
  Write-Host "OK: webhook received HOS_TestAlert"
} catch {
  Write-Host "WARN: couldn't find HOS_TestAlert in alert-webhook logs (is obs profile running?): $($_.Exception.Message)" -ForegroundColor Yellow
  Write-Host "Hint: start obs stack with .\\ops\\bootstrap.ps1 -Obs"
}


