# POST-RESET VERIFICATION
# Copy-paste this entire block into PowerShell

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== POST-RESET VERIFICATION ===" -ForegroundColor Cyan

Write-Host "[1] Docker Compose status..." -ForegroundColor Yellow
docker compose ps

Write-Host ""
Write-Host "[2] H-OS health endpoint..." -ForegroundColor Yellow
curl.exe -i http://localhost:3000/v1/health

Write-Host ""
Write-Host "[3] Running conformance.ps1..." -ForegroundColor Yellow
.\ops\conformance.ps1

Write-Host ""
Write-Host "[4] Running doctor.ps1..." -ForegroundColor Yellow
.\ops\doctor.ps1

Write-Host ""
Write-Host "[5] Running rc0_check.ps1..." -ForegroundColor Yellow
.\ops\rc0_check.ps1

Write-Host ""
Write-Host "[6] Running ops_status.ps1..." -ForegroundColor Yellow
.\ops\ops_status.ps1

Write-Host "=== VERIFICATION COMPLETE ===" -ForegroundColor Green















