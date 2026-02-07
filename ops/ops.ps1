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

  # Pass-through for run_ops_status.ps1 (useful for double-click runs)
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
  Write-Host "  ship       Publish main (gates + push) via ship_main.ps1" -ForegroundColor White
  Write-Host "  doctor     Repository doctor diagnostics" -ForegroundColor White
  Write-Host "  refresh    Frontend apply (restart) via frontend_refresh.ps1" -ForegroundColor White
  Write-Host "             Options: -Build (rebuild)" -ForegroundColor Gray
  Write-Host "  full       FULL_GATES pack (verify+contracts+governance)" -ForegroundColor White
  Write-Host "  rc0        RC0 readiness gate (rc0_check.ps1)" -ForegroundColor White
  Write-Host "             Options: -Ci" -ForegroundColor Gray
  Write-Host "  release    RC0 release bundle generator (release_bundle.ps1)" -ForegroundColor White
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
  Write-Host "  rc0-gate   RC0 gate (rc0_gate.ps1)" -ForegroundColor White
  Write-Host "  status-safe Run ops status in child process (run_ops_status.ps1)" -ForegroundColor White
  Write-Host ""
  Write-Host "Examples:" -ForegroundColor Yellow
  Write-Host "  .\ops\ops.ps1 up -StackProfile core" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 down" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 run -Profile Prototype" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 status" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 refresh -Build" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 ship" -ForegroundColor White
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
  { $_ -in @("full", "full_gates") } { Invoke-TargetScript -RelPath "full_gates.ps1"; break }
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
  { $_ -in @("status-safe", "status_safe", "run_status") } {
    $path = Join-Path $scriptDir "run_ops_status.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($Ci -and $Pause) { & $path -Ci -Pause }
    elseif ($Ci) { & $path -Ci }
    elseif ($Pause) { & $path -Pause }
    else { & $path }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
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
  { $_ -in @("ship", "publish", "ship-main", "ship_main") } { Invoke-TargetScript -RelPath "ship_main.ps1"; break }
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
    $path = Join-Path $scriptDir "rc0_gate.ps1"
    if (-not (Test-Path $path)) {
      Write-Host ("FAIL: script not found: {0}" -f $path) -ForegroundColor Red
      Invoke-OpsExit 1
      break
    }
    if ($Ci) { & $path -Ci } else { & $path }
    Invoke-OpsExit ([int]$global:LASTEXITCODE)
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

