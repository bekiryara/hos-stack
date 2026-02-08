param()

$ErrorActionPreference = "Stop"

Write-Host "DEPRECATED: work/hos/ops/bootstrap.ps1 is retired." -ForegroundColor Yellow
Write-Host "Use the single canonical entrypoint from repo root:" -ForegroundColor Yellow
Write-Host "  cd D:\stack" -ForegroundColor Gray
Write-Host "  docker compose up -d --build" -ForegroundColor Gray
Write-Host "  .\ops\ops.ps1 status" -ForegroundColor Gray
Write-Host "" 
Write-Host "Obs (optional): .\ops\ops.ps1 up -StackProfile obs" -ForegroundColor Gray
exit 1

