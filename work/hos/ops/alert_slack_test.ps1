param(
  [string]$AlertmanagerUrl = "http://localhost:9093"
)

$ErrorActionPreference = "Stop"

function Json($obj) { $obj | ConvertTo-Json -Compress -Depth 10 }

Write-Host "Slack alert test -> $AlertmanagerUrl"
Write-Host "NOTE: This script can only prove sending to Alertmanager. Delivery proof is the Slack message in your channel."

# 1) Basic readiness
try {
  $ready = & curl.exe -sS "$AlertmanagerUrl/-/ready"
  Write-Host "ready: $(Json $ready)"
} catch {
  Write-Host "ERROR: alertmanager not ready: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

# 2) Send a test alert
$now = [DateTime]::UtcNow
$alert = ,@{
  labels = @{
    alertname = "HOS_TestSlackAlert"
    severity  = "warning"
    source    = "ops/alert_slack_test.ps1"
  }
  annotations = @{
    summary = "H-OS test Slack alert (safe)"
    description = "Synthetic alert sent directly to Alertmanager. If Slack is configured, you should see it."
  }
  startsAt = $now.ToString("o")
  endsAt   = $now.AddMinutes(5).ToString("o")
}

try {
  $tmp = Join-Path $env:TEMP ("hos_slack_alert_" + [Guid]::NewGuid().ToString("N") + ".json")
  $json = (Json $alert)
  if (-not $json.TrimStart().StartsWith("[")) { $json = "[" + $json + "]" }
  $enc = New-Object System.Text.UTF8Encoding($false) # UTF-8 without BOM
  [System.IO.File]::WriteAllText($tmp, $json, $enc)

  $resp = Join-Path $env:TEMP ("hos_slack_alert_resp_" + [Guid]::NewGuid().ToString("N") + ".txt")
  $code = & curl.exe -sS -o $resp -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary ("@" + $tmp) "$AlertmanagerUrl/api/v2/alerts"
  if ($code -notmatch "^(200|201|202)$") {
    $body = ""
    try { $body = Get-Content -Raw $resp } catch {}
    throw "HTTP ${code}: $body"
  }
  Write-Host "sent: ok (HTTP $code)"
  Write-Host "Now verify in Slack: look for alertname=HOS_TestSlackAlert"
} catch {
  Write-Host "ERROR: failed to send test alert: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  try { if (Test-Path $tmp) { Remove-Item -Force $tmp } } catch {}
  try { if (Test-Path $resp) { Remove-Item -Force $resp } } catch {}
}


