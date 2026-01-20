param(
  [string]$OutDir,
  [switch]$SchemaOnly
)

$ErrorActionPreference = "Stop"

.$PSScriptRoot\\_lib.ps1
$docker = Get-DockerCmd

if (-not $OutDir) {
  # SECURITY: default outside the repo to reduce accidental leakage via repo zip/share.
  if ($env:LOCALAPPDATA) {
    $OutDir = Join-Path (Join-Path $env:LOCALAPPDATA "H-OS") "backups"
  } else {
    $OutDir = "backups"
  }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
if ($SchemaOnly) { $suffix = "schema" } else { $suffix = "data" }
$outFile = Join-Path $OutDir "hos-$ts.$suffix.sql"

if (-not $env:POSTGRES_PASSWORD) {
  Load-EnvFile ".env"
  Load-EnvFile ".env.local"
}

if (-not $env:POSTGRES_PASSWORD) {
  # Support secrets mode (bootstrap writes secrets/db_password.txt).
  $secret = Read-TextFile "secrets/db_password.txt"
  if ($secret) { $env:POSTGRES_PASSWORD = $secret }
}

if (-not $env:POSTGRES_PASSWORD) {
  throw "POSTGRES_PASSWORD gerekli. Env-mode için .env kullan; secrets-mode için secrets/db_password.txt oluştur (ops/bootstrap.ps1 -Secrets)."
}

$db = $env:POSTGRES_DB; if (-not $db) { $db = "hos" }
$user = $env:POSTGRES_USER; if (-not $user) { $user = "hos" }

Write-Host "Backup aliniyor -> $outFile"
if (-not $SchemaOnly) {
  Write-Host "WARNING: This backup includes table data and may contain PII. Store outside the repo and avoid sharing." -ForegroundColor Yellow
} else {
  Write-Host "NOTE: Schema-only backup (no table data)." -ForegroundColor DarkGray
}

# Use -T to disable pseudo-tty so redirection works reliably.
if ($SchemaOnly) {
  & $docker compose exec -T -e PGPASSWORD=$env:POSTGRES_PASSWORD db pg_dump --schema-only --no-owner --no-privileges -U $user -d $db > $outFile
} else {
  & $docker compose exec -T -e PGPASSWORD=$env:POSTGRES_PASSWORD db pg_dump -U $user -d $db > $outFile
}

Write-Host "OK: $outFile"



