param(
  [Parameter(Mandatory = $true)]
  [string]$InFile
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InFile)) {
  throw "Dosya bulunamadi: $InFile"
}

.$PSScriptRoot\\_lib.ps1
$docker = Get-DockerCmd

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

Write-Host "Restore basliyor <- $InFile"
Write-Host "Uyari: Bu islem hedef DB'ye yazacak. Eminsen devam et."

# Non-interactive environment: avoid prompts; user asked to continue. We proceed directly.
Get-Content $InFile | & $docker compose exec -T -e PGPASSWORD=$env:POSTGRES_PASSWORD db psql -U $user -d $db

Write-Host "OK: restore tamamlandi."



