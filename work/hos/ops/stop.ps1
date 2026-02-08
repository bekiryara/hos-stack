param()

$ErrorActionPreference = "Stop"

Write-Host "DEPRECATED: work/hos/ops/stop.ps1 is retired." -ForegroundColor Yellow
Write-Host "Use canonical shutdown from repo root:" -ForegroundColor Yellow
Write-Host "  cd D:\stack" -ForegroundColor Gray
Write-Host "  .\ops\ops.ps1 down -StackProfile all" -ForegroundColor Gray
exit 1



