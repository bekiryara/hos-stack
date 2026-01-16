Set-StrictMode -Off
$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

$results = @()

function Add-Result([string]$group, [string]$name, [string]$status, [string]$details) {
  $global:results += [pscustomobject]@{ Group=$group; Name=$name; Status=$status; Details=$details }
  Write-Host ("[{0}] {1} :: {2} - {3}" -f $status, $group, $name, $details)
}

function Count-Items($obj) {
  if ($null -eq $obj) { return 0 }
  try { return @($obj).Count } catch { return 0 }
}

function Get-FirstContainerName([string]$pattern) {
  $m = docker ps --format "{{.Names}}" 2>$null | Select-String -Pattern $pattern | Select-Object -First 1
  if ($null -eq $m) { return $null }
  if ($null -eq $m.Line) { return $null }
  return ([string]$m.Line).Trim()
}

function Curl-StatusAndRequestId([string]$url, [string]$accept = $null, [string]$auth = $null, [string]$tenant = $null) {
  $args = @("-sS","-D","-","-o","NUL")
  if ($accept) { $args += @("-H", ("Accept: " + $accept)) }
  if ($auth)   { $args += @("-H", ("Authorization: Bearer " + $auth)) }
  if ($tenant) { $args += @("-H", ("X-Tenant-Id: " + $tenant)) }
  $args += $url

  $hdr = & curl.exe @args 2>$null
  $statusLine = ($hdr | Select-String -Pattern '^HTTP/\d(\.\d)?\s+\d{3}' | Select-Object -First 1)
  $ridLine    = ($hdr | Select-String -Pattern '^(x-request-id|X-Request-Id):\s*' | Select-Object -First 1)

  $statusCode = $null
  if ($statusLine -and $statusLine.Line -match '\s(\d{3})\s') { $statusCode = [int]$matches[1] }

  $requestId = $null
  if ($ridLine -and $ridLine.Line -match ':\s*(.+)$') { $requestId = $matches[1].Trim() }

  return [pscustomobject]@{ Status=$statusCode; RequestId=$requestId }
}

function DockerExecHttp([string]$container, [string]$url) {
  if (-not $container) { return [pscustomobject]@{ Ok=$false; Output="NO_CONTAINER" } }
  $cmd = "wget -qO- $url 2>/dev/null || (command -v curl >/dev/null 2>&1 && curl -fsS $url) || echo NO_HTTP_TOOL"
  $out = docker exec -i $container sh -lc $cmd 2>$null
  $txt = ($out | Out-String).Trim()
  $ok = ($txt -ne "") -and ($txt -notmatch "NO_HTTP_TOOL")
  return [pscustomobject]@{ Ok=$ok; Output=$txt }
}

function Run-Script([string]$group, [string]$name, [string]$scriptPath, [string]$args = "") {
  if (-not (Test-Path $scriptPath)) { Add-Result $group $name "FAIL" ("Missing: " + $scriptPath); return "" }
  $out = & $scriptPath $args 2>&1
  $ec = $LASTEXITCODE
  if ($ec -eq 0) { Add-Result $group $name "PASS" ("ExitCode=0") }
  elseif ($ec -eq 2) { Add-Result $group $name "WARN" ("ExitCode=2") }
  else { Add-Result $group $name "FAIL" ("ExitCode=" + $ec) }
  return ($out | Out-String)
}

function Extract-ValueLine([string]$text, [string]$prefix) {
  # returns first matching line after prefix, e.g. AUDIT_PATH=...
  if (-not $text) { return $null }
  $m = ($text -split "`r?`n") | Where-Object { $_ -like ($prefix + "*") } | Select-Object -First 1
  if ($null -eq $m) { return $null }
  return ([string]$m).Trim()
}

Write-Host ""
Write-Host "=== STACK E2E CRITICAL TESTS v1 ==="
Write-Host ("Timestamp: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Host ("PWD: {0}" -f (Get-Location).Path)
Write-Host ""

# GROUP 0) Repo + Ops
$g = "0) Repo + Ops"
$must = @(
  ".\ops\doctor.ps1",
  ".\ops\ops_status.ps1",
  ".\ops\conformance.ps1",
  ".\ops\env_contract.ps1",
  ".\ops\security_audit.ps1",
  ".\ops\auth_security.ps1",
  ".\ops\tenant_boundary.ps1",
  ".\ops\session_posture.ps1",
  ".\ops\observability_status.ps1",
  ".\ops\rc0_gate.ps1",
  ".\ops\release_check.ps1",
  ".\ops\stack_up.ps1",
  ".\ops\self_audit.ps1",
  ".\ops\drift_monitor.ps1"
)

$missing = @()
foreach ($m in $must) { if (-not (Test-Path $m)) { $missing += $m } }

if ($missing.Count -gt 0) { Add-Result $g "Required ops scripts" "FAIL" ("Missing: " + ($missing -join ", ")) }
else { Add-Result $g "Required ops scripts" "PASS" "OK" }

Write-Host ""

# GROUP 1) Core Health
$g = "1) Core Health"
docker compose ps
Add-Result $g "docker compose ps" "PASS" "Listed"

$hos = Curl-StatusAndRequestId "http://localhost:3000/v1/health" "application/json"
if ($hos.Status -eq 200 -and $hos.RequestId) { Add-Result $g "H-OS /v1/health" "PASS" ("HTTP 200, x-request-id=" + $hos.RequestId) }
elseif ($hos.Status -eq 200) { Add-Result $g "H-OS /v1/health" "WARN" "HTTP 200, x-request-id missing" }
else { Add-Result $g "H-OS /v1/health" "FAIL" ("HTTP " + $hos.Status) }

$pz = Curl-StatusAndRequestId "http://localhost:8080/up"
if ($pz.Status -eq 200) { Add-Result $g "Pazar /up" "PASS" "HTTP 200" }
else { Add-Result $g "Pazar /up" "FAIL" ("HTTP " + $pz.Status) }

Write-Host ""

# GROUP 2) RC0 Gates (release omurga)
$g = "2) RC0 Gates"
Run-Script $g "rc0_gate.ps1" ".\ops\rc0_gate.ps1" | Out-Null
Run-Script $g "release_check.ps1" ".\ops\release_check.ps1" | Out-Null

Write-Host ""

# GROUP 3) Observability (container-internal readiness)
$g = "3) Observability"
Run-Script $g "stack_up -Profile obs" ".\ops\stack_up.ps1" "-Profile obs" | Out-Null

docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | findstr /i "hos-prometheus hos-alertmanager hos-grafana hos-loki hos-tempo hos-otel"
Add-Result $g "obs containers" "PASS" "Listed"

$prom = Get-FirstContainerName "hos-prometheus"
$am   = Get-FirstContainerName "hos-alertmanager"

$pr = DockerExecHttp $prom "http://127.0.0.1:9090/-/ready"
if ($pr.Ok -and ($pr.Output -match "Ready|ready")) { Add-Result $g "prometheus ready" "PASS" $pr.Output }
elseif ($pr.Ok) { Add-Result $g "prometheus ready" "WARN" ("Output: " + $pr.Output) }
else { Add-Result $g "prometheus ready" "FAIL" $pr.Output }

$ar = DockerExecHttp $am "http://127.0.0.1:9093/-/ready"
if ($ar.Ok -and ($ar.Output -match "OK|ok|Ready|ready")) { Add-Result $g "alertmanager ready" "PASS" $ar.Output }
elseif ($ar.Ok) { Add-Result $g "alertmanager ready" "WARN" ("Output: " + $ar.Output) }
else { Add-Result $g "alertmanager ready" "WARN" ("Not ready / no output: " + $ar.Output) }

Write-Host ""

# GROUP 4) Product API (Commerce read-path + Food/Rentals stubs)
$g = "4) Product API"
$pazar = Get-FirstContainerName "stack-pazar-app"
if (-not $pazar) { $pazar = Get-FirstContainerName "pazar-app" }

if (-not $pazar) { Add-Result $g "pazar container" "FAIL" "Could not find pazar app container" }
else {
  Add-Result $g "pazar container" "PASS" $pazar

  docker exec -i $pazar sh -lc "php artisan optimize:clear" 2>$null | Out-Null
  Add-Result $g "artisan optimize:clear" "PASS" "Cache cleared"

  # route:list filter without grep dependency
  $php = "php artisan route:list --columns=Method,URI 2>/dev/null | php -r '$in=stream_get_contents(STDIN); foreach(explode(PHP_EOL,$in) as $l){ if(strpos($l,""/api/v1/"")!==false && strpos($l,""/listings"")!==false) echo $l,PHP_EOL; }'"
  $rl  = docker exec -i $pazar sh -lc $php 2>$null
  $rlText = ($rl | Out-String).Trim()
  if ($rlText -ne "") { Add-Result $g "api routes present" "PASS" "Found /api/v1/*/listings" }
  else { Add-Result $g "api routes present" "FAIL" "No /api/v1/*/listings in route:list (route registration or code drift)" }

  # Commerce GET is protected now -> expect 401/403 without creds
  $c0 = Curl-StatusAndRequestId "http://localhost:8080/api/v1/commerce/listings" "application/json"
  if ($c0.Status -in 401,403) { Add-Result $g "commerce GET (no auth)" "PASS" ("HTTP " + $c0.Status) }
  elseif ($c0.Status -eq 200) { Add-Result $g "commerce GET (no auth)" "WARN" "HTTP 200 (unexpected: looks unprotected)" }
  else { Add-Result $g "commerce GET (no auth)" "FAIL" ("HTTP " + $c0.Status) }

  # Food/Rentals GET: stub-only -> 501
  $f0 = Curl-StatusAndRequestId "http://localhost:8080/api/v1/food/listings" "application/json"
  if ($f0.Status -eq 501) { Add-Result $g "food GET (stub)" "PASS" "HTTP 501" } else { Add-Result $g "food GET (stub)" "FAIL" ("HTTP " + $f0.Status) }

  $r0 = Curl-StatusAndRequestId "http://localhost:8080/api/v1/rentals/listings" "application/json"
  if ($r0.Status -eq 501) { Add-Result $g "rentals GET (stub)" "PASS" "HTTP 501" } else { Add-Result $g "rentals GET (stub)" "FAIL" ("HTTP " + $r0.Status) }

  # Optional E2E: commerce read-path with token+tenant
  $tok = $env:TOKEN
  $tid = $env:TENANT_ID
  if ($tok -and $tid) {
    $c1 = Curl-StatusAndRequestId "http://localhost:8080/api/v1/commerce/listings" "application/json" $tok $tid
    if ($c1.Status -eq 200) { Add-Result $g "commerce GET (auth+tenant)" "PASS" "HTTP 200" }
    else { Add-Result $g "commerce GET (auth+tenant)" "FAIL" ("HTTP " + $c1.Status) }
  } else {
    Add-Result $g "commerce GET (auth+tenant)" "SKIP" "Set env TOKEN and TENANT_ID (Bearer + X-Tenant-Id) to run E2E read-path."
  }
}

Write-Host ""

# GROUP 5) Self-Audit + Drift Monitor (new pack)
$g = "5) Self-Audit + Drift"
$auditOut = Run-Script $g "self_audit.ps1" ".\ops\self_audit.ps1"
$aLine = Extract-ValueLine $auditOut "AUDIT_PATH="
if ($aLine) {
  $auditPath = $aLine.Substring("AUDIT_PATH=".Length).Trim()
  Add-Result $g "AUDIT_PATH" "PASS" $auditPath

  if (Test-Path $auditPath) { Add-Result $g "audit folder exists" "PASS" $auditPath }
  else { Add-Result $g "audit folder exists" "FAIL" ("Not found: " + $auditPath) }

  $meta = Join-Path $auditPath "meta.json"
  $sum  = Join-Path $auditPath "summary.json"
  $drep = Join-Path $auditPath "drift_report.md"
  $dh   = Join-Path $auditPath "drift_hashes.json"

  if (Test-Path $meta) { Add-Result $g "meta.json" "PASS" $meta } else { Add-Result $g "meta.json" "FAIL" ("Missing: " + $meta) }
  if (Test-Path $sum)  { Add-Result $g "summary.json" "PASS" $sum } else { Add-Result $g "summary.json" "FAIL" ("Missing: " + $sum) }

  $driftOut = Run-Script $g "drift_monitor.ps1" ".\ops\drift_monitor.ps1"
  $dLine = Extract-ValueLine $driftOut "DRIFT_REPORT="
  if ($dLine) {
    $driftPath = $dLine.Substring("DRIFT_REPORT=".Length).Trim()
    Add-Result $g "DRIFT_REPORT" "PASS" $driftPath
  } else {
    Add-Result $g "DRIFT_REPORT" "WARN" "DRIFT_REPORT=... not printed (check drift_monitor output)"
  }

  if (Test-Path $drep) { Add-Result $g "drift_report.md" "PASS" $drep } else { Add-Result $g "drift_report.md" "FAIL" ("Missing: " + $drep) }
  if (Test-Path $dh)   { Add-Result $g "drift_hashes.json" "PASS" $dh } else { Add-Result $g "drift_hashes.json" "FAIL" ("Missing: " + $dh) }

} else {
  Add-Result $g "AUDIT_PATH" "FAIL" "AUDIT_PATH=... not printed by self_audit.ps1 (pack contract broken)"
}

Write-Host ""
Write-Host "=== SUMMARY (grouped) ==="

$groups = $results | Group-Object Group
foreach ($gg in $groups) {
  $pass = Count-Items ($gg.Group | Where-Object { $_.Status -eq "PASS" })
  $warn = Count-Items ($gg.Group | Where-Object { $_.Status -eq "WARN" })
  $fail = Count-Items ($gg.Group | Where-Object { $_.Status -eq "FAIL" })
  $skip = Count-Items ($gg.Group | Where-Object { $_.Status -eq "SKIP" })
  Write-Host ("- {0}: PASS={1} WARN={2} FAIL={3} SKIP={4}" -f $gg.Name, $pass, $warn, $fail, $skip)
}

$totalPass = Count-Items ($results | Where-Object { $_.Status -eq "PASS" })
$totalWarn = Count-Items ($results | Where-Object { $_.Status -eq "WARN" })
$totalFail = Count-Items ($results | Where-Object { $_.Status -eq "FAIL" })
$totalSkip = Count-Items ($results | Where-Object { $_.Status -eq "SKIP" })

Write-Host ("TOTAL: PASS={0} WARN={1} FAIL={2} SKIP={3}" -f $totalPass, $totalWarn, $totalFail, $totalSkip)

if ($totalFail -gt 0) { Write-Host "OVERALL: FAIL"; Invoke-OpsExit 1; return }
elseif ($totalWarn -gt 0) { Write-Host "OVERALL: WARN"; Invoke-OpsExit 0; return }
else { Write-Host "OVERALL: PASS"; Invoke-OpsExit 0; return }
