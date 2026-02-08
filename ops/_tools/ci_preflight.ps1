param(
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Info([string]$msg) { if (-not $Quiet) { Write-Host "[ci_preflight] $msg" -ForegroundColor Cyan } }
function Warn([string]$msg) { Write-Host "[ci_preflight] WARN: $msg" -ForegroundColor Yellow }

# Resolve repo root: ops/_tools -> ops -> repo root
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$secretsDir = Join-Path $repoRoot "work\hos\secrets"

Info "Repo root: $repoRoot"
Info "Secrets dir: $secretsDir"

New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null

# Minimal, deterministic CI secrets (NOT for production).
$dbPassword = "ci_db_password"
$jwtSecret = "ci_jwt_secret_" + ([guid]::NewGuid().ToString("N")) + ([guid]::NewGuid().ToString("N")) # > 32 chars
$databaseUrl = "postgresql://hos:$dbPassword@hos-db:5432/hos"

# Dummy Google OAuth config so /v1/auth/google/start can redirect (smoke checks).
$googleClientId = "ci-google-client-id"
$googleClientSecret = "ci-google-client-secret"
$googleRedirectUri = "http://localhost:3000/v1/auth/google/callback"

function Write-SecretFile([string]$name, [string]$value) {
  $path = Join-Path $secretsDir "$name.txt"
  # Use UTF8 without BOM; keep a single trailing newline out (some parsers are strict).
  $v = $value
  if ($null -eq $v) { $v = "" }
  [System.IO.File]::WriteAllText($path, ([string]$v).Trim(), (New-Object System.Text.UTF8Encoding($false)))
  Info "Wrote $name.txt"
}

Write-SecretFile -name "db_password" -value $dbPassword
Write-SecretFile -name "jwt_secret" -value $jwtSecret
Write-SecretFile -name "database_url" -value $databaseUrl
Write-SecretFile -name "google_client_id" -value $googleClientId
Write-SecretFile -name "google_client_secret" -value $googleClientSecret
Write-SecretFile -name "google_redirect_uri" -value $googleRedirectUri

# External volume required by docker-compose.yml (hos_db_data is external:true).
Info "Ensuring external docker volume hos_db_data exists..."
try {
  $existing = docker volume ls -q --filter "name=^hos_db_data$" 2>$null
  if ([string]::IsNullOrEmpty(($existing | Out-String).Trim())) {
    docker volume create hos_db_data | Out-Null
    Info "Created volume: hos_db_data"
  } else {
    Info "Volume already exists: hos_db_data"
  }
} catch {
  Warn "Could not ensure docker volume (docker may be unavailable): $($_.Exception.Message)"
}

Info "OK"

