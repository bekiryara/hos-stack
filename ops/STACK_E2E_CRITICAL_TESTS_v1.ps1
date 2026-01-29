param(
  # Default: V1 "critical path" only (runs on a normal dev box).
  # Opt-in flags enable heavier release/obs/product packs.
  [switch]$IncludeRelease,
  [switch]$IncludeObservability,
  [switch]$IncludeProduct,
  [switch]$IncludeSelfAudit
)

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
  # V1 store scope header uses X-Active-Tenant-Id (SPEC §5.2). Keep legacy name for old packs.
  if ($tenant) { $args += @("-H", ("X-Active-Tenant-Id: " + $tenant)) }
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
Write-Host ("Mode: IncludeRelease={0} IncludeObservability={1} IncludeProduct={2} IncludeSelfAudit={3}" -f $IncludeRelease, $IncludeObservability, $IncludeProduct, $IncludeSelfAudit)
Write-Host ""

# GROUP 0) Repo + Ops
$g = "0) Repo + Ops"
$must = @(
  # Core baseline
  ".\ops\verify.ps1",
  ".\ops\conformance.ps1",
  ".\ops\frontend_smoke.ps1",
  # Contracts (V1)
  ".\ops\catalog_contract_check.ps1",
  ".\ops\listing_contract_check.ps1",
  ".\ops\reservation_contract_check.ps1",
  ".\ops\rental_contract_check.ps1",
  ".\ops\order_contract_check.ps1",
  ".\ops\messaging_proxy_smoke.ps1",
  ".\ops\messaging_journey_check.ps1",
  # Customer portal read surfaces (requires dev token bootstrap)
  ".\ops\ensure_product_test_auth.ps1",
  ".\ops\account_portal_read_check.ps1",
  ".\ops\session_posture_check.ps1"
)

if ($IncludeRelease) {
  $must += @(
    ".\ops\public_ready_check.ps1",
    ".\ops\repo_payload_guard.ps1",
    ".\ops\closeouts_size_gate.ps1",
    ".\ops\security_audit.ps1",
    ".\ops\auth_security_check.ps1",
    ".\ops\tenant_boundary_check.ps1",
    ".\ops\ship_main.ps1"
  )
}

if ($IncludeObservability) {
  $must += @(
    ".\ops\observability_status.ps1",
    ".\ops\stack_up.ps1"
  )
}

if ($IncludeSelfAudit) {
  $must += @(
    ".\ops\self_audit.ps1",
    ".\ops\drift_monitor.ps1"
  )
}

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

#
# GROUP 2) V1 Critical Gates
#
$g = "2) V1 Critical Gates"
Run-Script $g "verify.ps1" ".\ops\verify.ps1" | Out-Null
Run-Script $g "conformance.ps1" ".\ops\conformance.ps1" | Out-Null
Run-Script $g "frontend_smoke.ps1" ".\ops\frontend_smoke.ps1" | Out-Null

Write-Host ""

#
# GROUP 3) V1 Contracts (customer + transactions + messaging)
#
$g = "3) V1 Contract Gates"
Run-Script $g "catalog_contract_check.ps1" ".\ops\catalog_contract_check.ps1" | Out-Null
Run-Script $g "listing_contract_check.ps1" ".\ops\listing_contract_check.ps1" | Out-Null
Run-Script $g "reservation_contract_check.ps1" ".\ops\reservation_contract_check.ps1" | Out-Null
Run-Script $g "rental_contract_check.ps1" ".\ops\rental_contract_check.ps1" | Out-Null
Run-Script $g "order_contract_check.ps1" ".\ops\order_contract_check.ps1" | Out-Null
Run-Script $g "messaging_proxy_smoke.ps1" ".\ops\messaging_proxy_smoke.ps1" | Out-Null
Run-Script $g "messaging_journey_check.ps1" ".\ops\messaging_journey_check.ps1" | Out-Null

Write-Host ""

#
# GROUP 4) Customer Portal Read Surfaces
#
$g = "4) Customer Portal Read"
Run-Script $g "ensure_product_test_auth.ps1" ".\ops\ensure_product_test_auth.ps1" | Out-Null
Run-Script $g "account_portal_read_check.ps1" ".\ops\account_portal_read_check.ps1" | Out-Null
Run-Script $g "session_posture_check.ps1" ".\ops\session_posture_check.ps1" | Out-Null

Write-Host ""

#
# GROUP 5) Optional packs (release/obs/product/self-audit)
#
if ($IncludeSelfAudit) {
  $g = "5) Self-Audit + Drift"
  $auditOut = Run-Script $g "self_audit.ps1" ".\ops\self_audit.ps1"
  $aLine = Extract-ValueLine $auditOut "AUDIT_PATH="
  if ($aLine) {
    $auditPath = $aLine.Substring("AUDIT_PATH=".Length).Trim()
    Add-Result $g "AUDIT_PATH" "PASS" $auditPath
  } else {
    Add-Result $g "AUDIT_PATH" "FAIL" "AUDIT_PATH=... not printed by self_audit.ps1 (pack contract broken)"
  }

  Run-Script $g "drift_monitor.ps1" ".\ops\drift_monitor.ps1" | Out-Null
  Write-Host ""
}

if ($IncludeObservability) {
  $g = "5) Observability"
  Run-Script $g "observability_status.ps1" ".\ops\observability_status.ps1" | Out-Null
  Write-Host ""
}

if ($IncludeProduct) {
  $g = "5) Product (optional)"
  Run-Script $g "product_e2e.ps1" ".\ops\product_e2e.ps1" | Out-Null
  Write-Host ""
}

if ($IncludeRelease) {
  $g = "5) Release (optional)"
  Run-Script $g "public_ready_check.ps1" ".\ops\public_ready_check.ps1" | Out-Null
  Run-Script $g "repo_payload_guard.ps1" ".\ops\repo_payload_guard.ps1" | Out-Null
  Run-Script $g "closeouts_size_gate.ps1" ".\ops\closeouts_size_gate.ps1" | Out-Null
  Run-Script $g "security_audit.ps1" ".\ops\security_audit.ps1" | Out-Null
  Run-Script $g "tenant_boundary_check.ps1" ".\ops\tenant_boundary_check.ps1" | Out-Null
  Write-Host ""
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
elseif ($totalWarn -gt 0) { Write-Host "OVERALL: WARN"; Invoke-OpsExit 2; return }
else { Write-Host "OVERALL: PASS"; Invoke-OpsExit 0; return }
