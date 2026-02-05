#!/usr/bin/env pwsh
# full_gates.ps1 - Single local "FULL GATES" entrypoint
# Purpose: Run the same FULL_GATES pack used in docker_paket.bat, from a single script.
# Order:
#   1) verify
#   2) openapi_contract
#   3) conformance
#   4) v2_gate (0-targets)
#   5) pazar_spine_check
#   6) messaging_contract_check
#
# Exit codes: 0 PASS, 1 FAIL

$ErrorActionPreference = "Stop"

# Load safe exit helper if present
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
  . "${scriptDir}\_lib\ops_exit.ps1"
  Initialize-OpsExit
}
if (-not (Get-Command Invoke-OpsExit -ErrorAction SilentlyContinue)) {
  function Invoke-OpsExit {
    param([int]$Code = 1)
    exit $Code
  }
}

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

Write-Host "=== FULL GATES ===" -ForegroundColor Cyan
Write-Host ("Timestamp: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Gray

Run-Step -Label "1) verify" -ScriptRel "verify.ps1"
Run-Step -Label "2) openapi_contract" -ScriptRel "openapi_contract.ps1"
Run-Step -Label "3) conformance" -ScriptRel "conformance.ps1"
Run-Step -Label "4) v2_gate" -ScriptRel "v2_gate.ps1"
Run-Step -Label "5) pazar_spine_check" -ScriptRel "pazar_spine_check.ps1"
Run-Step -Label "6) messaging_contract_check" -ScriptRel "messaging_contract_check.ps1"

Write-Host ""
Write-Host "PASS: FULL GATES" -ForegroundColor Green
Invoke-OpsExit 0

