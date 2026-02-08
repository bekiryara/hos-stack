param()

$ErrorActionPreference = "Stop"

Write-Host "DEPRECATED: work/hos/ops/alert_test.ps1 is retired." -ForegroundColor Yellow
Write-Host "Use canonical ops from repo root (obs is optional):" -ForegroundColor Yellow
Write-Host "  cd D:\stack" -ForegroundColor Gray
Write-Host "  .\ops\ops.ps1 up -StackProfile obs" -ForegroundColor Gray
Write-Host "  .\ops\ops.ps1 status -Ci" -ForegroundColor Gray
exit 1


