#!/usr/bin/env pwsh
# ops.ps1 - Human-friendly dispatcher for ops scripts
# Goal: stop memorizing filenames. One entrypoint, many commands.
# PowerShell 5.1 compatible.
#
# Examples:
#   .\ops\ops.ps1 full
#   .\ops\ops.ps1 status
#   .\ops\ops.ps1 run -Profile Prototype
#   .\ops\ops.ps1 openapi
#
# Exit codes: passthrough from underlying script

param(
  [Parameter(Position = 0)]
  [string]$Command = "help",

  # Pass-through for ops_run.ps1
  [ValidateSet('Prototype', 'Full')]
  [string]$Profile = 'Prototype',
  [switch]$CheckDemoSeed
  ,

  # Pass-through for stack_up/stack_down.ps1
  [ValidateSet('core', 'obs', 'all')]
  [string]$StackProfile = 'core',

  # Pass-through for CI-aware runners
  [switch]$Ci,

  # Pass-through for frontend_refresh.ps1
  [switch]$Build,

  # Pass-through for status-safe runner (useful for double-click runs)
  [switch]$Pause
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") { . "${scriptDir}\_lib\ops_exit.ps1"; Initialize-OpsExit }
if (-not (Get-Command Invoke-OpsExit -ErrorAction SilentlyContinue)) {
  function Invoke-OpsExit { param([int]$Code = 1) exit $Code }
}

function Show-Help {
  Write-Host "=== OPS DISPATCHER ===" -ForegroundColor Cyan
  Write-Host "Usage:" -ForegroundColor Yellow
  Write-Host "  .\ops\ops.ps1 <command> [options]" -ForegroundColor White
  Write-Host ""
  Write-Host "Golden commands (keep these in your muscle memory):" -ForegroundColor Yellow
  Write-Host "  up         Stack up (core|obs|all) via stack_up.ps1" -ForegroundColor White
  Write-Host "             Options: -StackProfile core|obs|all" -ForegroundColor Gray
  Write-Host "  down       Stack down (core|obs|all) via stack_down.ps1" -ForegroundColor White
  Write-Host "             Options: -StackProfile core|obs|all" -ForegroundColor Gray
  Write-Host "  run        Daily pack (ops_run) -Profile Prototype|Full" -ForegroundColor White
  Write-Host "             Options: -Profile Prototype|Full [-CheckDemoSeed]" -ForegroundColor Gray
  Write-Host "  status     Ops dashboard (ops_status.ps1)" -ForegroundColor White
  Write-Host "             Options: -Ci (include optional checks)" -ForegroundColor Gray
  Write-Host "  smoke      Smoke pack (world_status_check + smoke_surface)" -ForegroundColor White
  Write-Host "  ship       Publish main (gates + push)" -ForegroundColor White
  Write-Host "  doctor     Repository doctor diagnostics" -ForegroundColor White
  Write-Host "  refresh    Frontend apply (restart) via frontend_refresh.ps1" -ForegroundColor White
  Write-Host "             Options: -Build (rebuild)" -ForegroundColor Gray
  Write-Host "  full       FULL GATES pack (verify+contracts+governance)" -ForegroundColor White
  Write-Host "  rc0        RC0 readiness gate (rc0_check.ps1)" -ForegroundColor White
  Write-Host "             Options: -Ci" -ForegroundColor Gray
  Write-Host "  release    RC0 release bundle generator (release_bundle.ps1)" -ForegroundColor White
  Write-Host "             Options: -Ci" -ForegroundColor Gray
  Write-Host "  release-check RC0 release checklist enforcement" -ForegroundColor White
  Write-Host "             Options: -Ci" -ForegroundColor Gray
  Write-Host ""
  Write-Host "Other commands (still supported):" -ForegroundColor Yellow
  Write-Host "  prototype  Prototype/demo verification (prototype_v1)" -ForegroundColor White
  Write-Host "  verify     Stack health (verify.ps1)" -ForegroundColor White
  Write-Host "  openapi    OpenAPI contract (openapi_contract.ps1)" -ForegroundColor White
  Write-Host "  conformance Architecture conformance (conformance.ps1)" -ForegroundColor White
  Write-Host "  pazar-spine Pazar spine check (pazar_spine_check.ps1)" -ForegroundColor White
  Write-Host "  v2-gate    V2 gate (0-targets) (v2_gate.ps1)" -ForegroundColor White
  Write-Host "  messaging  Messaging contract (messaging_contract_check.ps1)" -ForegroundColor White
  Write-Host "  rc0-gate   RC0 gate" -ForegroundColor White
  Write-Host "  status-safe Run ops status in child process" -ForegroundColor White
  Write-Host "  env-preflight Tool: node/npm/docker preflight (env_preflight.ps1)" -ForegroundColor White
  Write-Host "  release-note Tool: generate RELEASE_NOTE.md from CHANGELOG (release_note.ps1)" -ForegroundColor White
  Write-Host "  repo-inventory Tool: repository inventory report (repo_inventory_report.ps1)" -ForegroundColor White
  Write-Host "  ngrok-backend Tool: expose backend via ngrok (start_ngrok_backend.ps1)" -ForegroundColor White
  Write-Host "  route-diag Tool: pazar route surface diagnostic (pazar_route_surface_diag.ps1)" -ForegroundColor White
  Write-Host "  perf-baseline Tool: perf baseline runner (perf_baseline.ps1)" -ForegroundColor White
  Write-Host ""
  Write-Host "Examples:" -ForegroundColor Yellow
  Write-Host "  .\ops\ops.ps1 up -StackProfile core" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 down" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 run -Profile Prototype" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 status" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 refresh -Build" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 ship" -ForegroundColor White
}

function Invoke-FullGatesPack {
  # Inline implementation of former ops/full_gates.ps1
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Stop"
  try {
    Write-Host "=== FULL GATES ===" -ForegroundColor Cyan
    Write-Host ("Timestamp: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Gray

    function Run-Step {
      param(
        [Parameter(Mandatory=$true)][string]$Label,
        [Parameter(Mandatory=$true)][string]$ScriptRel
      )
      Write-Host ""
      Write-Host ("[FULL] {0}" -f $Label) -ForegroundColor Yellow
      $path = Join-Path $scriptDir $ScriptRel
      if (-not (Test-Path $path)) {
        Write-Host ("FAIL: missing {0}" -f $path) -ForegroundColor Red
        Invoke-OpsExit 1
        return
      }
      & $path
      if ($LASTEXITCODE -ne 0) {
        Write-Host ("FAIL: {0} (exit={1})" -f $ScriptRel, $LASTEXITCODE) -ForegroundColor Red
        Invoke-OpsExit 1
        return
      }
      Write-Host ("PASS: {0}" -f $ScriptRel) -ForegroundColor Green
    }

    Run-Step -Label "1) verify" -ScriptRel "verify.ps1"
    Run-Step -Label "2) openapi_contract" -ScriptRel "openapi_contract.ps1"
    Run-Step -Label "3) conformance" -ScriptRel "conformance.ps1"
    Run-Step -Label "4) v2_gate" -ScriptRel "v2_gate.ps1"
    Run-Step -Label "5) pazar_spine_check" -ScriptRel "pazar_spine_check.ps1"
    Run-Step -Label "6) messaging_contract_check" -ScriptRel "messaging_contract_check.ps1"

    Write-Host ""
    Write-Host "PASS: FULL GATES" -ForegroundColor Green
    Invoke-OpsExit 0
  } finally {
    $ErrorActionPreference = $oldEap
  }
}

function Invoke-OpsStatusSafe {
  # Inline implementation of former ops/run_ops_status.ps1
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $repoRoot = Split-Path -Parent $scriptDir
  Push-Location $repoRoot
  try {
    $opsStatusPath = Join-Path $scriptDir "ops_status.ps1"
    if (-not (Test-Path $opsStatusPath)) {
      Write-Host ("[FAIL] ops_status.ps1 not found: {0}" -f $opsStatusPath) -ForegroundColor Red
      $global:LASTEXITCODE = 1
      if ($Pause) {
        Write-Host ""
        Write-Host "Press Enter to close..." -ForegroundColor Gray
        Read-Host | Out-Null
      }
      Invoke-OpsExit 1
      return 1
    }

    Write-Host "=== Running Ops Status (Safe Mode) ===" -ForegroundColor Cyan
    if ($Ci) { Write-Host "CI Mode: Exit code will terminate job on failure" -ForegroundColor Gray }
    else { Write-Host "Local Mode: Terminal will remain open" -ForegroundColor Gray }
    Write-Host "Executing in child PowerShell process..." -ForegroundColor Gray
    Write-Host ""

    $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", "`"$opsStatusPath`""
    )
    if ($Ci) { $args += "-Ci" }

    $process = Start-Process -FilePath $psExe -ArgumentList $args -WorkingDirectory $repoRoot -Wait -PassThru
    $code = [int]$process.ExitCode

    Write-Host ""
    Write-Host "=== Ops Status Completed ===" -ForegroundColor Cyan
    Write-Host "ExitCode=$code" -ForegroundColor $(if ($code -eq 0) { "Green" } elseif ($code -eq 2) { "Yellow" } else { "Red" })

    $global:LASTEXITCODE = $code
    if ($Pause) {
      Write-Host ""
      Write-Host "Press Enter to close..." -ForegroundColor Gray
      Read-Host | Out-Null
    }

    Invoke-OpsExit $code
    return $code
  } finally {
    Pop-Location
    $ErrorActionPreference = $oldEap
  }
}

function Invoke-SmokePack {
  # Canonical smoke entrypoint (replaces legacy ops/smoke.ps1)
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $repoRoot = Split-Path -Parent $scriptDir
  Push-Location $repoRoot
  try {
    Write-Host "=== SMOKE PACK ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""

    $steps = @(
      @{ Name = "World Status"; Path = (Join-Path $scriptDir "world_status_check.ps1"); Args = @() },
      @{ Name = "Smoke Surface"; Path = (Join-Path $scriptDir "smoke_surface.ps1"); Args = @() }
    )

    $exitCodes = @()
    foreach ($s in $steps) {
      Write-Host ("[SMOKE] {0}" -f $s.Name) -ForegroundColor Yellow
      if (-not (Test-Path $s.Path)) {
        Write-Host ("FAIL: missing script: {0}" -f $s.Path) -ForegroundColor Red
        $exitCodes += 1
        continue
      }
      try {
        & $s.Path @($s.Args)
        $exitCodes += [int]$global:LASTEXITCODE
      } catch {
        Write-Host ("FAIL: {0} crashed: {1}" -f $s.Name, $_.Exception.Message) -ForegroundColor Red
        $exitCodes += 1
      }
      Write-Host ""
    }

    $final = 0
    if ($exitCodes -contains 1) { $final = 1 }
    elseif ($exitCodes -contains 2) { $final = 2 }

    if ($final -eq 0) { Write-Host "SMOKE PACK: PASS" -ForegroundColor Green }
    elseif ($final -eq 2) { Write-Host "SMOKE PACK: WARN" -ForegroundColor Yellow }
    else { Write-Host "SMOKE PACK: FAIL" -ForegroundColor Red }

    Invoke-OpsExit $final
  } finally {
    Pop-Location
    $ErrorActionPreference = $oldEap
  }
}

function Invoke-ShipMain {
  # Inline implementation of former ops/ship_main.ps1
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Stop"
  $repoRoot = Split-Path -Parent $scriptDir
  Push-Location $repoRoot
  try {
    Write-Host "=== SHIP MAIN (WP-45) ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""

    function Sanitize-Ascii {
      param([string]$text)
      return $text -replace '[^\x00-\x7F]', ''
    }
    function Write-Sanitized {
      param([string]$text, [string]$Color = "White")
      $sanitized = Sanitize-Ascii $text
      Write-Host $sanitized -ForegroundColor $Color
    }

    Write-Host "[PRE-FLIGHT] Checking prerequisites..." -ForegroundColor Yellow

    $currentBranch = (git branch --show-current).Trim()
    if ($currentBranch -ne "main") {
      Write-Host "FAIL: Current branch is not main (found: $currentBranch)" -ForegroundColor Red
      Write-Host "  Ship main requires working on main branch" -ForegroundColor Yellow
      Invoke-OpsExit 1
      return
    }
    Write-Host "PASS: Current branch is main" -ForegroundColor Green

    $gitStatus = git status --porcelain
    if ($gitStatus) {
      Write-Host "FAIL: Working tree is not clean" -ForegroundColor Red
      Write-Host "  Uncommitted changes:" -ForegroundColor Yellow
      $gitStatus | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
      Write-Host "  Fix: Commit or stash changes before shipping" -ForegroundColor Yellow
      Invoke-OpsExit 1
      return
    }
    Write-Host "PASS: Working tree is clean" -ForegroundColor Green

    Write-Host ""
    Write-Host "[GATES] Running quality gates..." -ForegroundColor Yellow

    $gateScripts = @(
      ".\ops\update_code_index.ps1",
      ".\ops\verify_wp_closeouts.ps1",
      ".\ops\secret_scan.ps1",
      ".\ops\public_ready_check.ps1",
      ".\ops\repo_payload_guard.ps1",
      ".\ops\closeouts_size_gate.ps1",
      ".\ops\conformance.ps1",
      ".\ops\frontend_smoke.ps1"
    )

    $gateIndex = 1
    foreach ($script in $gateScripts) {
      $scriptName = Split-Path $script -Leaf
      Write-Host "  [$gateIndex] Running $scriptName..." -ForegroundColor Gray
      if (-not (Test-Path $script)) {
        Write-Host "FAIL: $scriptName not present (required gate)" -ForegroundColor Red
        Invoke-OpsExit 1
        return
      }
      try {
        if ($scriptName -eq "update_code_index.ps1") {
          $output = & $script -DryRun -Gate 2>&1
        } elseif ($scriptName -eq "verify_wp_closeouts.ps1") {
          $output = & $script -Gate 2>&1
        } else {
          $output = & $script 2>&1
        }
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
          Write-Host "FAIL: $scriptName returned exit code $exitCode" -ForegroundColor Red
          $output | ForEach-Object { Write-Sanitized $_ "Gray" }
          Invoke-OpsExit 1
          return
        } else {
          Write-Host "PASS: $scriptName" -ForegroundColor Green
        }
      } catch {
        Write-Sanitized "FAIL: $scriptName failed: $($_.Exception.Message)" "Red"
        Invoke-OpsExit 1
        return
      }
      $gateIndex++
    }

    Write-Host ""
    Write-Host "[GIT] Synchronizing with origin..." -ForegroundColor Yellow

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      Write-Host "  Pulling from origin/main (rebase)..." -ForegroundColor Gray
      $pullOutput = git pull --rebase origin main 2>&1
      $pullExitCode = $LASTEXITCODE
      if ($pullExitCode -ne 0) {
        Write-Sanitized "FAIL: git pull --rebase failed with exit code $pullExitCode" "Red"
        $pullOutput | ForEach-Object { Write-Sanitized $_ "Gray" }
        Invoke-OpsExit 1
        return
      }
      Write-Host "PASS: Pulled from origin/main" -ForegroundColor Green

      Write-Host "  Pushing to origin/main..." -ForegroundColor Gray
      $pushOutput = git push origin main 2>&1
      $pushExitCode = $LASTEXITCODE
      if ($pushExitCode -ne 0) {
        Write-Sanitized "FAIL: git push failed with exit code $pushExitCode" "Red"
        $pushOutput | ForEach-Object { Write-Sanitized $_ "Gray" }
        Invoke-OpsExit 1
        return
      }
      Write-Host "PASS: Pushed to origin/main" -ForegroundColor Green
    } finally {
      $ErrorActionPreference = $old
    }

    Write-Host ""
    Write-Host "=== SHIP MAIN: PASS ===" -ForegroundColor Green
    Write-Host "  All gates: PASS" -ForegroundColor Gray
    Write-Host "  Git sync: PASS" -ForegroundColor Gray
    Write-Host "  Main branch published to origin" -ForegroundColor Gray
    Invoke-OpsExit 0
  } finally {
    Pop-Location
    $ErrorActionPreference = $oldEap
  }
}

function Invoke-Rc0Gate {
  # Inline RC0 Gate pack (former ops/rc0_gate.ps1), kept for backwards compatibility.
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $repoRoot = Split-Path -Parent $scriptDir
  Push-Location $repoRoot
  try {
    Write-Host "=== RC0 RELEASE GATE ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""

    $script:results = @()

    function Invoke-RC0Check {
      param(
        [string]$CheckName,
        [string]$ScriptPath,
        [string[]]$Arguments = @()
      )
      Write-Host "Running $CheckName..." -ForegroundColor Yellow

      $exitCode = 0
      $status = "PASS"
      $notes = ""

      if (-not (Test-Path $ScriptPath)) {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Script not found: $ScriptPath"
        $script:results += [PSCustomObject]@{ Check=$CheckName; Status=$status; ExitCode=$exitCode; Notes=$notes }
        return @{ Status=$status; ExitCode=$exitCode; Notes=$notes }
      }

      try {
        if ($null -eq $Arguments) { $Arguments = @() }
        $scriptOutput = & $ScriptPath @Arguments 2>&1 | Out-String
        $exitCode = [int]$LASTEXITCODE

        if ($exitCode -eq 0) { $status = "PASS" }
        elseif ($exitCode -eq 2) { $status = "WARN" }
        else { $status = "FAIL" }

        $outputLines = $scriptOutput -split "`n" | Where-Object { $_.Trim() -ne "" }
        if ($outputLines.Count -gt 0) {
          $notes = ($outputLines[-3..-1] | Where-Object { $_ -ne $null }) -join "; "
          if ($notes.Length -gt 100) { $notes = $notes.Substring(0, 97) + "..." }
        }
      } catch {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Error: $($_.Exception.Message)"
      }

      $script:results += [PSCustomObject]@{ Check=$CheckName; Status=$status; ExitCode=$exitCode; Notes=$notes }
      return @{ Status=$status; ExitCode=$exitCode; Notes=$notes }
    }

    function Test-ErrorContractInline {
      Write-Host "Running Error Contract Check..." -ForegroundColor Yellow
      $status = "PASS"
      $exitCode = 0
      $notes = ""
      try {
        $helper = Join-Path $scriptDir "_lib\error_contract.ps1"
        if (-not (Test-Path $helper)) {
          $status = "FAIL"; $exitCode = 1; $notes = "Missing helper: $helper"
        } else {
          . $helper
          $res = Invoke-ErrorContractCheck -BaseUrl "http://localhost:8080"
          $status = [string]$res.Status
          $exitCode = [int]$res.ExitCode
          $notes = [string]$res.Notes
        }
      } catch {
        $status = "FAIL"; $exitCode = 1; $notes = "Error: $($_.Exception.Message)"
      }
      $script:results += [PSCustomObject]@{ Check="M) Error Contract"; Status=$status; ExitCode=$exitCode; Notes=$notes }
      return @{ Status=$status; ExitCode=$exitCode; Notes=$notes }
    }

    function Test-ObservabilityStatus {
      Write-Host "Running Observability Status Check..." -ForegroundColor Yellow
      $status = "WARN"
      $exitCode = 2
      $notes = ""

      $obsComposeFile = "work\hos\docker-compose.yml"
      if (-not (Test-Path $obsComposeFile)) {
        $notes = "Observability compose file not found (WARN only - observability is optional)"
        $script:results += [PSCustomObject]@{ Check="J) Observability Status"; Status=$status; ExitCode=$exitCode; Notes=$notes }
        return @{ Status=$status; ExitCode=$exitCode; Notes=$notes }
      }

      try {
        $prometheusReady = $null
        $alertmanagerReady = $null
        $promExit = 1
        $amExit = 1

        try {
          $resp = Invoke-WebRequest -Uri "http://localhost:9090/-/ready" -Method Get -TimeoutSec 5 -ErrorAction Stop
          $prometheusReady = $resp.Content
          $promExit = 0
        } catch {
          $promExit = 1
        }
        try {
          $resp = Invoke-WebRequest -Uri "http://localhost:9093/-/ready" -Method Get -TimeoutSec 5 -ErrorAction Stop
          $alertmanagerReady = $resp.Content
          $amExit = 0
        } catch {
          $amExit = 1
        }

        if ($promExit -eq 0 -and $amExit -eq 0 -and $prometheusReady -and $alertmanagerReady) {
          $status = "PASS"; $exitCode = 0; $notes = "Prometheus and Alertmanager are ready"
        } else {
          $status = "WARN"; $exitCode = 2; $notes = "Observability services not ready/accessible (WARN only)"
        }
      } catch {
        $status = "WARN"; $exitCode = 2; $notes = "Observability services not available (WARN only): $($_.Exception.Message)"
      }

      $script:results += [PSCustomObject]@{ Check="J) Observability Status"; Status=$status; ExitCode=$exitCode; Notes=$notes }
      return @{ Status=$status; ExitCode=$exitCode; Notes=$notes }
    }

    Write-Host "=== Running RC0 Gate Checks ===" -ForegroundColor Cyan
    Write-Host ""

    # 0) RC0 Check (aggregate check - must pass)
    $rc0CheckResult = Invoke-RC0Check -CheckName "0) RC0 Check" -ScriptPath (Join-Path $scriptDir "rc0_check.ps1") -Arguments $(if ($Ci) { @("-Ci") } else { @() })
    if ($rc0CheckResult.Status -eq "FAIL") {
      Write-Host ""
      Write-Host "RC0 Check failed - RC0 Gate cannot proceed" -ForegroundColor Red
      Write-Host ""
      Invoke-OpsExit 1
      return
    }

    # A) Repository Doctor
    Invoke-RC0Check -CheckName "A) Repository Doctor" -ScriptPath (Join-Path $scriptDir "doctor.ps1") | Out-Null
    # B) Stack Verification (RC0 mode: /up required)
    Invoke-RC0Check -CheckName "B) Stack Verification" -ScriptPath (Join-Path $scriptDir "verify.ps1") -Arguments @("-Release") | Out-Null
    # C) Architecture Conformance
    Invoke-RC0Check -CheckName "C) Architecture Conformance" -ScriptPath (Join-Path $scriptDir "conformance.ps1") | Out-Null
    # D) Environment Contract
    Invoke-RC0Check -CheckName "D) Environment Contract" -ScriptPath (Join-Path $scriptDir "env_contract.ps1") | Out-Null
    # E) Security Audit
    Invoke-RC0Check -CheckName "E) Security Audit" -ScriptPath (Join-Path $scriptDir "security_audit.ps1") | Out-Null
    # F) Auth Security Check
    Invoke-RC0Check -CheckName "F) Auth Security Check" -ScriptPath (Join-Path $scriptDir "auth_security_check.ps1") | Out-Null
    # G) Tenant Boundary Check
    Invoke-RC0Check -CheckName "G) Tenant Boundary Check" -ScriptPath (Join-Path $scriptDir "tenant_boundary_check.ps1") | Out-Null
    # H) Session Posture Check
    $session = Invoke-RC0Check -CheckName "H) Session Posture Check" -ScriptPath (Join-Path $scriptDir "session_posture_check.ps1")
    $appEnv = $env:APP_ENV
    if (($appEnv -eq "local") -or ($appEnv -eq "dev") -or (-not $appEnv)) {
      if ($session.Status -eq "FAIL") {
        $idx = $script:results.Count - 1
        if ($idx -ge 0) {
          $script:results[$idx].Status = "WARN"
          $script:results[$idx].ExitCode = 2
          $script:results[$idx].Notes = "Session posture FAIL in local/dev (mapped to WARN): $($script:results[$idx].Notes)"
        }
      }
    }
    # I) SLO Check (non-blocking; map FAIL->WARN)
    $slo = Invoke-RC0Check -CheckName "I) SLO Check (N=10)" -ScriptPath (Join-Path $scriptDir "slo_check.ps1") -Arguments @("-N", "10")
    if ($slo.Status -eq "FAIL") {
      $idx = $script:results.Count - 1
      if ($idx -ge 0) {
        $script:results[$idx].Status = "WARN"
        $script:results[$idx].ExitCode = 2
        $script:results[$idx].Notes = "SLO check FAIL (mapped to WARN): $($script:results[$idx].Notes)"
      }
    }
    # J) Observability Status (non-blocking)
    Test-ObservabilityStatus | Out-Null
    # K) Routes Snapshot (non-blocking - real FAIL stays FAIL)
    Invoke-RC0Check -CheckName "K) Routes Snapshot" -ScriptPath (Join-Path $scriptDir "routes_snapshot.ps1") | Out-Null
    # L) Schema Snapshot (blocking)
    Invoke-RC0Check -CheckName "L) Schema Snapshot" -ScriptPath (Join-Path $scriptDir "schema_snapshot.ps1") | Out-Null
    # M) Error Contract
    Test-ErrorContractInline | Out-Null
    # N) Release Bundle (SKIP; manual)
    $script:results += [PSCustomObject]@{ Check="N) Release Bundle"; Status="SKIP"; ExitCode=0; Notes="Run: .\\ops\\ops.ps1 release" }

    Write-Host ""
    Write-Host "=== RC0 GATE RESULTS ===" -ForegroundColor Cyan
    Write-Host ""
    $script:results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

    $actual = $script:results | Where-Object { $_.Status -in @("PASS","WARN","FAIL","SKIP") }
    $failCount = ($actual | Where-Object { $_.Status -eq "FAIL" }).Count
    $warnCount = ($actual | Where-Object { $_.Status -eq "WARN" }).Count
    $passCount = ($actual | Where-Object { $_.Status -eq "PASS" }).Count
    $skipCount = ($actual | Where-Object { $_.Status -eq "SKIP" }).Count

    Write-Host ""
    Write-Host "Summary: $passCount PASS, $warnCount WARN, $failCount FAIL, $skipCount SKIP" -ForegroundColor Gray
    Write-Host ""

    if ($failCount -gt 0) {
      Write-Host "RC0 GATE: FAIL ($failCount blocking failures)" -ForegroundColor Red
      Write-Host ""
      if (Test-Path (Join-Path $scriptDir "incident_bundle.ps1")) {
        Write-Host "Generating incident bundle..." -ForegroundColor Yellow
        try { & (Join-Path $scriptDir "incident_bundle.ps1") 2>&1 | Out-Null } catch { }
      }
      Invoke-OpsExit 1
      return
    }
    if ($warnCount -gt 0) {
      Write-Host "RC0 GATE: WARN ($warnCount warnings, no blocking failures)" -ForegroundColor Yellow
      Invoke-OpsExit 2
      return
    }
    Write-Host "RC0 GATE: PASS (All blocking checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
  } finally {
    Pop-Location
    $ErrorActionPreference = $oldEap
  }
}

function Invoke-ReleaseCheck {
  # Inline implementation of former ops/release_check.ps1
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $repoRoot = Split-Path -Parent $scriptDir
  Push-Location $repoRoot
  try {
    Write-Host "=== RC0 RELEASE CHECK ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""

    $script:releaseCheckResults = @()
    function Add-CheckResult {
      param([string]$CheckName,[string]$Status,[int]$ExitCode,[string]$Notes = "")
      $script:releaseCheckResults += [PSCustomObject]@{ Check=$CheckName; Status=$Status; ExitCode=$ExitCode; Notes=$Notes }
    }

    Write-Host "A) Checking git status..." -ForegroundColor Yellow
    try {
      $gitStatus = & git status --porcelain 2>&1
      if ($LASTEXITCODE -ne 0) {
        Add-CheckResult -CheckName "A) Git Status Clean" -Status "FAIL" -ExitCode 1 -Notes "Git command failed: $gitStatus"
      } elseif ($gitStatus) {
        $uncommittedFiles = ($gitStatus | Measure-Object -Line).Lines
        Add-CheckResult -CheckName "A) Git Status Clean" -Status "FAIL" -ExitCode 1 -Notes "$uncommittedFiles uncommitted change(s) found. Commit or stash changes before release."
      } else {
        Add-CheckResult -CheckName "A) Git Status Clean" -Status "PASS" -ExitCode 0 -Notes "Working tree is clean"
      }
    } catch {
      Add-CheckResult -CheckName "A) Git Status Clean" -Status "FAIL" -ExitCode 1 -Notes "Error: $($_.Exception.Message)"
    }

    Write-Host "B) Running RC0 gate..." -ForegroundColor Yellow
    try {
      $rc0GateExit = 0
      $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
      $opsEntry = Join-Path $scriptDir "ops.ps1"
      if (-not (Test-Path $opsEntry)) {
        throw "ops.ps1 not found: $opsEntry"
      }
      $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$opsEntry`"",
        "rc0-gate"
      )
      if ($Ci) { $args += "-Ci" }
      $p = Start-Process -FilePath $psExe -ArgumentList $args -WorkingDirectory $repoRoot -Wait -PassThru
      $rc0GateExit = [int]$p.ExitCode
      $status = if ($rc0GateExit -eq 0) { "PASS" } elseif ($rc0GateExit -eq 2) { "WARN" } else { "FAIL" }
      $notes = if ($status -eq "PASS") { "All blocking checks passed" } elseif ($status -eq "WARN") { "Warnings present (non-blocking)" } else { "Blocking failures detected" }
      Add-CheckResult -CheckName "B) RC0 Gate" -Status $status -ExitCode $rc0GateExit -Notes $notes
    } catch {
      Add-CheckResult -CheckName "B) RC0 Gate" -Status "FAIL" -ExitCode 1 -Notes "Error: $($_.Exception.Message)"
    }

    Write-Host "C) Checking required documentation..." -ForegroundColor Yellow
    $requiredDocs = @(
      @{ Path = "docs\ARCHITECTURE.md"; Name = "Architecture Overview" },
      @{ Path = "docs\REPO_LAYOUT.md"; Name = "Repository Layout" },
      @{ Path = "docs\runbooks\incident.md"; Name = "Incident Runbook" }
    )
    $missingDocs = @()
    foreach ($doc in $requiredDocs) { if (-not (Test-Path $doc.Path)) { $missingDocs += $doc.Name } }
    if ($missingDocs.Count -gt 0) {
      Add-CheckResult -CheckName "C) Required Documentation" -Status "FAIL" -ExitCode 1 -Notes "Missing: $($missingDocs -join ', ')"
    } else {
      Add-CheckResult -CheckName "C) Required Documentation" -Status "PASS" -ExitCode 0 -Notes "All required docs present"
    }

    Write-Host "D) Checking contract snapshots..." -ForegroundColor Yellow
    $requiredSnapshots = @(
      @{ Path = "ops\snapshots\routes.pazar.json"; Name = "Routes Snapshot" },
      @{ Path = "ops\snapshots\schema.pazar.sql"; Name = "Schema Snapshot" }
    )
    $missingSnapshots = @()
    foreach ($snapshot in $requiredSnapshots) { if (-not (Test-Path $snapshot.Path)) { $missingSnapshots += $snapshot.Name } }
    if ($missingSnapshots.Count -gt 0) {
      Add-CheckResult -CheckName "D) Contract Snapshots" -Status "FAIL" -ExitCode 1 -Notes "Missing: $($missingSnapshots -join ', ')"
    } else {
      Add-CheckResult -CheckName "D) Contract Snapshots" -Status "PASS" -ExitCode 0 -Notes "All snapshots present"
    }

    Write-Host "E) Checking VERSION file..." -ForegroundColor Yellow
    $versionPath = "VERSION"
    if (-not (Test-Path $versionPath)) {
      Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "VERSION file not found"
    } else {
      try {
        $versionContent = (Get-Content $versionPath -Raw).Trim()
        if ([string]::IsNullOrWhiteSpace($versionContent)) {
          Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "VERSION file is empty"
        } elseif ($versionContent -match '^(\d+\.\d+\.\d+)(-rc\d+)?$') {
          Add-CheckResult -CheckName "E) VERSION File" -Status "PASS" -ExitCode 0 -Notes "Version: $versionContent (format valid)"
        } else {
          Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "Invalid version format: $versionContent (expected: X.Y.Z or X.Y.Z-rcN)"
        }
      } catch {
        Add-CheckResult -CheckName "E) VERSION File" -Status "FAIL" -ExitCode 1 -Notes "Error reading VERSION: $($_.Exception.Message)"
      }
    }

    Write-Host ""
    Write-Host "=== RELEASE CHECK RESULTS ===" -ForegroundColor Cyan
    Write-Host ""
    $script:releaseCheckResults | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

    $failCount = ($script:releaseCheckResults | Where-Object { $_.Status -eq "FAIL" }).Count
    $warnCount = ($script:releaseCheckResults | Where-Object { $_.Status -eq "WARN" }).Count
    $passCount = ($script:releaseCheckResults | Where-Object { $_.Status -eq "PASS" }).Count

    Write-Host ""
    Write-Host "Summary: $passCount PASS, $warnCount WARN, $failCount FAIL" -ForegroundColor Gray
    Write-Host ""

    if ($failCount -gt 0) { Write-Host "RELEASE CHECK: FAIL ($failCount blocking failures)" -ForegroundColor Red; Invoke-OpsExit 1; return }
    if ($warnCount -gt 0) { Write-Host "RELEASE CHECK: WARN ($warnCount warnings, no blocking failures)" -ForegroundColor Yellow; Invoke-OpsExit 2; return }
    Write-Host "RELEASE CHECK: PASS (All checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
  } finally {
    Pop-Location
    $ErrorActionPreference = $oldEap
  }
}

function Invoke-TargetScript {
  param(
    [Parameter(Mandatory = $true)][string]$RelPath
  )
  $path = Join-Path $scriptDir $RelPath
  if (-not (Test-Path $path)) {
    Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
    Invoke-OpsExit 1
    return
  }
  & $path
  $code = [int]$global:LASTEXITCODE
  Invoke-OpsExit $code
}

$cmd = "help"
if (-not [string]::IsNullOrWhiteSpace($Command)) {
  $cmd = $Command.ToLowerInvariant().Trim()
}
switch ($cmd) {
  { $_ -in @("help", "-h", "--help", "/?") } { Show-Help; Invoke-OpsExit 0; break }
  { $_ -in @("up", "stack-up", "stack_up") } {
    $path = Join-Path $scriptDir "stack_up.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    & $path -Profile $StackProfile
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("down", "stack-down", "stack_down") } {
    $path = Join-Path $scriptDir "stack_down.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    & $path -Profile $StackProfile
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("full", "full_gates") } { Invoke-FullGatesPack; break }
  { $_ -in @("prototype", "demo", "prototype_v1") } {
    $path = Join-Path $scriptDir "_extras\prototype\prototype_v1.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($CheckDemoSeed) {
      & $path -CheckDemoSeed
    } else {
      & $path
    }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("status", "ops_status") } {
    $path = Join-Path $scriptDir "ops_status.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($Ci) { & $path -Ci } else { & $path }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("smoke", "smoke-pack", "smoke_pack") } { Invoke-SmokePack; break }
  { $_ -in @("env-preflight", "env_preflight") } { Invoke-TargetScript -RelPath "env_preflight.ps1"; break }
  { $_ -in @("release-note", "release_note") } { Invoke-TargetScript -RelPath "release_note.ps1"; break }
  { $_ -in @("repo-inventory", "repo_inventory") } { Invoke-TargetScript -RelPath "repo_inventory_report.ps1"; break }
  { $_ -in @("ngrok-backend", "ngrok_backend") } { Invoke-TargetScript -RelPath "start_ngrok_backend.ps1"; break }
  { $_ -in @("route-diag", "route_diag") } { Invoke-TargetScript -RelPath "pazar_route_surface_diag.ps1"; break }
  { $_ -in @("perf-baseline", "perf_baseline") } { Invoke-TargetScript -RelPath "perf_baseline.ps1"; break }
  { $_ -in @("status-safe", "status_safe", "run_status") } {
    Invoke-OpsStatusSafe | Out-Null
    break
  }
  { $_ -in @("run", "ops_run") } {
    $path = Join-Path $scriptDir "ops_run.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($CheckDemoSeed) {
      & $path -Profile $Profile -CheckDemoSeed
    } else {
      & $path -Profile $Profile
    }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("ship", "publish", "ship-main", "ship_main") } { Invoke-ShipMain; break }
  { $_ -in @("doctor") } { Invoke-TargetScript -RelPath "doctor.ps1"; break }
  { $_ -in @("refresh", "frontend-refresh", "frontend_refresh") } {
    $path = Join-Path $scriptDir "frontend_refresh.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($Build) { & $path -Build } else { & $path }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("rc0", "rc0-check", "rc0_check") } {
    $path = Join-Path $scriptDir "rc0_check.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($Ci) { & $path -Ci } else { & $path }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("rc0-gate", "rc0_gate") } {
    Invoke-Rc0Gate
    break
  }
  { $_ -in @("release-check", "release_check") } {
    Invoke-ReleaseCheck
    break
  }
  { $_ -in @("release", "release-bundle", "release_bundle") } {
    $path = Join-Path $scriptDir "release_bundle.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($Ci) { & $path -Ci } else { & $path }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
    break
  }
  { $_ -in @("verify") } { Invoke-TargetScript -RelPath "verify.ps1"; break }
  { $_ -in @("openapi", "openapi_contract") } { Invoke-TargetScript -RelPath "openapi_contract.ps1"; break }
  { $_ -in @("conformance") } { Invoke-TargetScript -RelPath "conformance.ps1"; break }
  { $_ -in @("pazar-spine", "pazar_spine") } { Invoke-TargetScript -RelPath "pazar_spine_check.ps1"; break }
  { $_ -in @("v2-gate", "v2_gate", "gate-v2") } { Invoke-TargetScript -RelPath "v2_gate.ps1"; break }
  { $_ -in @("messaging", "messaging_contract") } { Invoke-TargetScript -RelPath "messaging_contract_check.ps1"; break }
  default {
    Write-Host ("Unknown command: {0}" -f $Command) -ForegroundColor Red
    Write-Host ""
    Show-Help
    Invoke-OpsExit 1
    break
  }
}

