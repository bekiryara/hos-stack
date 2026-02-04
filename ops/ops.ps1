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
  Write-Host "Commands:" -ForegroundColor Yellow
  Write-Host "  full       Run FULL_GATES pack (recommended)" -ForegroundColor White
  Write-Host "  prototype  Run prototype/demo verification" -ForegroundColor White
  Write-Host "  status     Run ops_status dashboard" -ForegroundColor White
  Write-Host "  run        Run daily pack (ops_run) with -Profile Prototype|Full" -ForegroundColor White
  Write-Host "  verify     Run verify.ps1 (stack health)" -ForegroundColor White
  Write-Host "  openapi    Run openapi_contract.ps1" -ForegroundColor White
  Write-Host "  conformance Run conformance.ps1" -ForegroundColor White
  Write-Host "  pazar-spine Run pazar_spine_check.ps1" -ForegroundColor White
  Write-Host "  messaging  Run messaging_contract_check.ps1" -ForegroundColor White
  Write-Host ""
  Write-Host "Examples:" -ForegroundColor Yellow
  Write-Host "  .\ops\ops.ps1 full" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 prototype" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 run -Profile Full" -ForegroundColor White
  Write-Host "  .\ops\ops.ps1 run -Profile Prototype -CheckDemoSeed" -ForegroundColor White
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
  { $_ -in @("status", "ops_status") } { Invoke-TargetScript -RelPath "ops_status.ps1"; break }
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
  { $_ -in @("verify") } { Invoke-TargetScript -RelPath "verify.ps1"; break }
  { $_ -in @("openapi", "openapi_contract") } { Invoke-TargetScript -RelPath "openapi_contract.ps1"; break }
  { $_ -in @("conformance") } { Invoke-TargetScript -RelPath "conformance.ps1"; break }
  { $_ -in @("pazar-spine", "pazar_spine") } { Invoke-TargetScript -RelPath "pazar_spine_check.ps1"; break }
  { $_ -in @("messaging", "messaging_contract") } { Invoke-TargetScript -RelPath "messaging_contract_check.ps1"; break }
  default {
    Write-Host ("Unknown command: {0}" -f $Command) -ForegroundColor Red
    Write-Host ""
    Show-Help
    Invoke-OpsExit 1
    break
  }
}

