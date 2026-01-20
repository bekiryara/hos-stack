param(
  [switch]$Prod
)

$ErrorActionPreference = 'Stop'

Write-Host "H-OS bootstrap" -ForegroundColor Cyan
Write-Host "Repo: $PSScriptRoot\.." -ForegroundColor DarkGray

Set-Location (Join-Path $PSScriptRoot '..')

if ($Prod) {
  if (-not $env:GRAFANA_ADMIN_USER) { $env:GRAFANA_ADMIN_USER = 'admin' }
  if (-not $env:GRAFANA_ADMIN_PASSWORD) { $env:GRAFANA_ADMIN_PASSWORD = 'admin' }
  docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.ports.yml up -d --build
} else {
  docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d --build
}

Write-Host ""
Write-Host "OK. Health:" -ForegroundColor Green
Write-Host "  curl.exe -sS -i http://localhost:3000/v1/health"

