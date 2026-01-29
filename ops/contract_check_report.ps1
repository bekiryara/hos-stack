# contract_check_report.ps1 - Contract Report (Catalog + Listings)
# Single report point for contract alignment checks.
# PowerShell 5.1 compatible, ASCII-only output.

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== CONTRACT CHECK REPORT ===" -ForegroundColor Cyan
Write-Host ("Timestamp: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) -ForegroundColor Gray
Write-Host ("PWD: {0}" -f (Get-Location).Path) -ForegroundColor Gray
Write-Host ""

function Run-Check([string]$name, [string]$path) {
  if (-not (Test-Path $path)) {
    return [pscustomobject]@{ Name = $name; Path = $path; Status = "FAIL"; ExitCode = 127 }
  }

  Write-Host ("Running: {0} ({1})" -f $name, $path) -ForegroundColor Yellow
  & $path 2>&1 | Out-Host
  $ec = $LASTEXITCODE

  if ($ec -eq 0) {
    return [pscustomobject]@{ Name = $name; Path = $path; Status = "PASS"; ExitCode = 0 }
  }
  elseif ($ec -eq 2) {
    return [pscustomobject]@{ Name = $name; Path = $path; Status = "WARN"; ExitCode = 2 }
  }
  else {
    return [pscustomobject]@{ Name = $name; Path = $path; Status = "FAIL"; ExitCode = $ec }
  }
}

$checks = @(
  @{ Name = "Catalog Contract"; Path = ".\\ops\\catalog_contract_check.ps1" },
  @{ Name = "Listing Contract"; Path = ".\\ops\\listing_contract_check.ps1" }
)

$results = @()
foreach ($c in $checks) {
  $results += Run-Check $c.Name $c.Path
  Write-Host ""
}

Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize Name, Status, ExitCode, Path

$hasFail = $results | Where-Object { $_.Status -eq "FAIL" }
if ($hasFail) {
  Write-Host ""
  Write-Host "OVERALL STATUS: FAIL" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "OVERALL STATUS: PASS" -ForegroundColor Green
exit 0

