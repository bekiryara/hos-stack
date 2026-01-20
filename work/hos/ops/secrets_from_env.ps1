param(
  [string]$OutDir = "secrets",
  [switch]$Apply,
  [switch]$Force,
  [switch]$SkipGoogle,
  [switch]$SkipDatabaseUrl
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Write-Utf8NoBom {
  param([string]$Path, [string]$Value)
  $enc = New-Object System.Text.UTF8Encoding($false) # UTF-8 without BOM
  [System.IO.File]::WriteAllText($Path, $Value, $enc)
}

function Get-Env {
  param([string]$Key)
  $v = [Environment]::GetEnvironmentVariable($Key)
  if ($null -eq $v) { return "" }
  return $v.Trim()
}

function Plan-Write {
  param(
    [string]$Path,
    [string]$Label,
    [string]$Value,
    [switch]$AllowEmpty
  )

  if (-not $AllowEmpty -and (-not $Value)) {
    return @{ action = "missing"; path = $Path; label = $Label }
  }

  $exists = Test-Path $Path
  if ($exists -and (-not $Force)) {
    return @{ action = "skip"; path = $Path; label = $Label }
  }

  # NOTE: PowerShell 5.1 doesn't support the ternary operator (?:).
  if ($Apply) {
    return @{ action = "write"; path = $Path; label = $Label; value = $Value }
  }
  return @{ action = "plan"; path = $Path; label = $Label; value = $Value }
}

Ensure-Dir $OutDir

Write-Host "secrets_from_env:"
Write-Host " - OutDir: $OutDir"
if ($Apply) {
  Write-Host " - Mode:   APPLY (write files)"
} else {
  Write-Host " - Mode:   DRY-RUN (no writes)"
}
Write-Host " - Force:  $([string]$Force)"
Write-Host ""

# Required for docker-compose.secrets.yml:
$pgUser = Get-Env "POSTGRES_USER"; if (-not $pgUser) { $pgUser = "hos" }
$pgDb   = Get-Env "POSTGRES_DB";   if (-not $pgDb)   { $pgDb = "hos" }
$pgPass = Get-Env "POSTGRES_PASSWORD"
$jwt    = Get-Env "JWT_SECRET"
$dbUrl  = Get-Env "DATABASE_URL"

$dbPassFile = Join-Path $OutDir "db_password.txt"
$jwtFile    = Join-Path $OutDir "jwt_secret.txt"
$dbUrlFile  = Join-Path $OutDir "database_url.txt"

$plans = New-Object System.Collections.Generic.List[object]
$plans.Add((Plan-Write -Path $dbPassFile -Label "db_password" -Value $pgPass)) | Out-Null
$plans.Add((Plan-Write -Path $jwtFile -Label "jwt_secret" -Value $jwt)) | Out-Null

if (-not $SkipDatabaseUrl) {
  if (-not $dbUrl) {
    if ($pgPass) {
      # Best-effort derive. Note: if password contains reserved URL characters, it should be URL-encoded.
      $dbUrl = "postgresql://$pgUser`:$pgPass@db:5432/$pgDb"
    }
  }
  $plans.Add((Plan-Write -Path $dbUrlFile -Label "database_url" -Value $dbUrl)) | Out-Null
}

if (-not $SkipGoogle) {
  $gId = Get-Env "GOOGLE_CLIENT_ID"
  $gSecret = Get-Env "GOOGLE_CLIENT_SECRET"
  $gRedir = Get-Env "GOOGLE_REDIRECT_URI"

  $gIdFile = Join-Path $OutDir "google_client_id.txt"
  $gSecretFile = Join-Path $OutDir "google_client_secret.txt"
  $gRedirFile = Join-Path $OutDir "google_redirect_uri.txt"

  # Google is optional: allow empty placeholders so compose secrets can still work without OAuth.
  $plans.Add((Plan-Write -Path $gIdFile -Label "google_client_id" -Value $gId -AllowEmpty)) | Out-Null
  $plans.Add((Plan-Write -Path $gSecretFile -Label "google_client_secret" -Value $gSecret -AllowEmpty)) | Out-Null
  $plans.Add((Plan-Write -Path $gRedirFile -Label "google_redirect_uri" -Value $gRedir -AllowEmpty)) | Out-Null
}

$missing = @($plans | Where-Object { $_.action -eq "missing" })
if ($missing.Count -gt 0) {
  Write-Host "Missing required env values (files not written):" -ForegroundColor Yellow
  foreach ($m in $missing) { Write-Host (" - {0}: {1}" -f $m.label, $m.path) }
  Write-Host ""
  Write-Host "Set env vars (e.g. in CI/Vault injection) and re-run with -Apply." -ForegroundColor Yellow
  exit 2
}

foreach ($p in $plans) {
  if ($p.action -eq "skip") {
    Write-Host ("SKIP: {0} (exists) -> {1}" -f $p.label, $p.path) -ForegroundColor DarkGray
    continue
  }
  if ($p.action -eq "plan") {
    Write-Host ("PLAN: {0} -> {1}" -f $p.label, $p.path)
    continue
  }
  if ($p.action -eq "write") {
    # Never echo secrets. Just write.
    Write-Utf8NoBom -Path $p.path -Value ($p.value + "`n")
    Write-Host ("OK:   {0} -> {1}" -f $p.label, $p.path) -ForegroundColor Green
    continue
  }
}

if (-not $Apply) {
  Write-Host ""
  Write-Host "Dry-run done. To write the files, re-run with: .\\ops\\secrets_from_env.ps1 -Apply" -ForegroundColor Yellow
} else {
  Write-Host ""
  Write-Host "Done. You can now run secrets mode:" -ForegroundColor Green
  Write-Host "  docker compose -f docker-compose.yml -f docker-compose.secrets.yml up -d --build"
}


