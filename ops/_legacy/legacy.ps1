#!/usr/bin/env pwsh
# legacy.ps1 - Legacy/utility pack (NON-CANONICAL)
# Purpose: reduce ops/ root clutter by collecting "sometimes useful" tools under one entrypoint.
# This pack MUST NOT be used by CI / ops_status / release gates.
# PowerShell 5.1 compatible.

param(
  [Parameter(Position = 0)]
  [string]$Command = "help",

  [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
  [string[]]$Args = @()
)

$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$opsDir = Split-Path -Parent $here
$repoRoot = Split-Path -Parent $opsDir
$toolsDir = Join-Path $here "tools"

function Show-Help {
  Write-Host "=== OPS LEGACY PACK (NON-CANONICAL) ===" -ForegroundColor Cyan
  Write-Host "Usage:" -ForegroundColor Yellow
  Write-Host "  .\ops\_legacy\legacy.ps1 <command> [args]" -ForegroundColor White
  Write-Host ""
  Write-Host "Commands:" -ForegroundColor Yellow
  Write-Host "  env-preflight     node/npm/docker preflight" -ForegroundColor White
  Write-Host "  repo-inventory    repo inventory report (largest files, suspicious root files)" -ForegroundColor White
  Write-Host "  ngrok-backend     expose localhost:8080 via ngrok" -ForegroundColor White
  Write-Host "  route-diag        pazar route surface diagnostic (read-only evidence)" -ForegroundColor White
  Write-Host "  perf-baseline     latency baseline (warmup + p95)" -ForegroundColor White
  Write-Host "  release-note      generate RELEASE_NOTE.md from CHANGELOG" -ForegroundColor White
  Write-Host "  drift-monitor     drift monitor (writes drift_report.md under latest audit)" -ForegroundColor White
  Write-Host "  hos-db-verify     post-reset verification checklist" -ForegroundColor White
  Write-Host "  hos-db-reset      HOS DB dev reset + core restore (DANGEROUS)" -ForegroundColor White
  Write-Host "  hos-db-recovery   HOS DB corruption recovery (DANGEROUS)" -ForegroundColor White
  Write-Host ""
  Write-Host "Note:" -ForegroundColor Yellow
  Write-Host "  - This is NOT part of ops core. It is for manual, occasional use." -ForegroundColor Gray
  Write-Host "  - For canonical ops, use: .\\ops\\ops.ps1 help" -ForegroundColor Gray
}

function Invoke-Tool {
  param(
    [Parameter(Mandatory=$true)][string]$RelTool,
    [string[]]$ToolArgs = @()
  )

  $path = Join-Path $toolsDir $RelTool
  if (-not (Test-Path $path)) {
    Write-Host ("FAIL: legacy tool not found: {0}" -f $path) -ForegroundColor Red
    exit 1
  }

  if ($null -eq $ToolArgs) { $ToolArgs = @() }
  Push-Location $repoRoot
  try {
    & $path @ToolArgs
    exit ([int]$global:LASTEXITCODE)
  } finally {
    Pop-Location
  }
}

$cmd = "help"
if (-not [string]::IsNullOrWhiteSpace($Command)) { $cmd = $Command.ToLowerInvariant().Trim() }

switch ($cmd) {
  { $_ -in @("help", "-h", "--help", "/?") } { Show-Help; exit 0 }
  { $_ -in @("env-preflight", "env_preflight") } { Invoke-Tool -RelTool "env_preflight.ps1" -ToolArgs $Args }
  { $_ -in @("repo-inventory", "repo_inventory") } { Invoke-Tool -RelTool "repo_inventory_report.ps1" -ToolArgs $Args }
  { $_ -in @("ngrok-backend", "ngrok_backend") } { Invoke-Tool -RelTool "start_ngrok_backend.ps1" -ToolArgs $Args }
  { $_ -in @("route-diag", "route_diag") } { Invoke-Tool -RelTool "pazar_route_surface_diag.ps1" -ToolArgs $Args }
  { $_ -in @("perf-baseline", "perf_baseline") } { Invoke-Tool -RelTool "perf_baseline.ps1" -ToolArgs $Args }
  { $_ -in @("release-note", "release_note") } { Invoke-Tool -RelTool "release_note.ps1" -ToolArgs $Args }
  { $_ -in @("drift-monitor", "drift_monitor") } { Invoke-Tool -RelTool "drift_monitor.ps1" -ToolArgs $Args }
  { $_ -in @("hos-db-verify", "hos_db_verify") } { Invoke-Tool -RelTool "hos_db_verify.ps1" -ToolArgs $Args }
  { $_ -in @("hos-db-reset", "hos_db_reset") } { Invoke-Tool -RelTool "hos_db_reset_safe.ps1" -ToolArgs $Args }
  { $_ -in @("hos-db-recovery", "hos_db_recovery") } { Invoke-Tool -RelTool "hos_db_recovery.ps1" -ToolArgs $Args }
  default {
    Write-Host ("Unknown legacy command: {0}" -f $Command) -ForegroundColor Red
    Write-Host ""
    Show-Help
    exit 1
  }
}

