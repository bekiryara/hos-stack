param()

$ErrorActionPreference = "Stop"

Write-Host "DEPRECATED: work/hos/ops/clean.ps1 is retired." -ForegroundColor Yellow
Write-Host "If you need repo hygiene, use canonical doctor/status from repo root:" -ForegroundColor Yellow
Write-Host "  cd D:\stack" -ForegroundColor Gray
Write-Host "  .\ops\ops.ps1 doctor" -ForegroundColor Gray
Write-Host "  .\ops\ops.ps1 status -Ci" -ForegroundColor Gray
exit 1


