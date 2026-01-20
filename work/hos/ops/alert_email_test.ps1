param(
  [string]$AlertmanagerUrl = "http://localhost:9093",
  [string]$MailpitApi = "http://localhost:8025"
)

$ErrorActionPreference = "Stop"

function Json($obj) { ConvertTo-Json -InputObject $obj -Depth 10 }

Write-Host "Email alert test"
Write-Host "Alertmanager: $AlertmanagerUrl"
Write-Host "Mailpit:      $MailpitApi"

# 1) Ensure endpoints are reachable
try {
  $ready = & curl.exe -sS "$AlertmanagerUrl/-/ready"
  Write-Host "alertmanager ready: $ready"
} catch {
  Write-Host "ERROR: alertmanager not reachable. Start with: .\\ops\\bootstrap.ps1 -Obs -MailpitAlerts" -ForegroundColor Red
  exit 1
}

try {
  & curl.exe -sS "$MailpitApi/api/v1/messages" | Out-Null
} catch {
  Write-Host "ERROR: mailpit not reachable. Start with: .\\ops\\bootstrap.ps1 -Obs -MailpitAlerts" -ForegroundColor Red
  exit 1
}

# 2) Send a synthetic alert directly to Alertmanager
$now = [DateTime]::UtcNow
$alert = ,@{
  labels = @{
    alertname = "HOS_TestEmailAlert"
    severity  = "critical"
    source    = "ops/alert_email_test.ps1"
  }
  annotations = @{
    summary = "H-OS test email alert (safe)"
    description = "Synthetic alert sent directly to Alertmanager; should arrive to Mailpit inbox."
  }
  startsAt = $now.ToString("o")
  endsAt   = $now.AddMinutes(5).ToString("o")
}

$tmp = Join-Path $env:TEMP ("hos_alert_email_" + [Guid]::NewGuid().ToString("N") + ".json")
$resp = Join-Path $env:TEMP ("hos_alert_email_resp_" + [Guid]::NewGuid().ToString("N") + ".txt")
try {
  $json = Json $alert
  # Ensure JSON is an array even if PowerShell collapses single-item arrays in some contexts.
  if (-not $json.TrimStart().StartsWith("[")) { $json = "[" + $json + "]" }
  $enc = New-Object System.Text.UTF8Encoding($false) # UTF-8 without BOM
  [System.IO.File]::WriteAllText($tmp, $json, $enc)

  $code = & curl.exe -sS -o $resp -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary ("@" + $tmp) "$AlertmanagerUrl/api/v2/alerts"
  if ($code -notmatch "^(200|201|202)$") {
    $body = ""
    try { $body = Get-Content -Raw $resp } catch {}
    throw "HTTP ${code}: $body"
  }
  Write-Host "sent: ok (HTTP $code)"
} finally {
  try { if (Test-Path $tmp) { Remove-Item -Force $tmp } } catch {}
  try { if (Test-Path $resp) { Remove-Item -Force $resp } } catch {}
}

# 3) Proof: Mailpit inbox contains the alert
Write-Host "waiting for email to arrive..."
for ($i=1; $i -le 20; $i++) {
  Start-Sleep -Seconds 1
  try {
    $raw = & curl.exe -sS "$MailpitApi/api/v1/messages"
    if ($raw -and ($raw | Select-String -SimpleMatch "HOS_TestEmailAlert")) {
      Write-Host "OK: email received in Mailpit (found HOS_TestEmailAlert)."
      Write-Host "Open inbox: $MailpitApi"
      exit 0
    }
  } catch {
    # ignore transient errors
  }
}

Write-Host "WARN: did not find HOS_TestEmailAlert in Mailpit within 20s." -ForegroundColor Yellow
Write-Host "Hint: check Mailpit UI: $MailpitApi and Alertmanager logs: docker compose logs --tail 200 alertmanager" -ForegroundColor Yellow


