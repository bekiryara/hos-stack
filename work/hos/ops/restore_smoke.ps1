param(
  [string]$InFile,
  [string]$OutDir = "backups-test",
  [int]$TimeoutSec = 60,
  [switch]$IncludeData,
  [switch]$KeepDump
)

$ErrorActionPreference = "Stop"

.$PSScriptRoot\\_lib.ps1
$docker = Get-DockerCmd

function New-RandomHex {
  param([int]$Bytes = 24)
  $buf = New-Object byte[] ($Bytes)
  $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
  try { $rng.GetBytes($buf) } finally { $rng.Dispose() }
  return ($buf | ForEach-Object { $_.ToString("x2") }) -join ""
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$createdDump = $false
$success = $false

if (-not $InFile) {
  # Create a fresh backup from the running compose DB.
  # SECURITY: default to schema-only to avoid generating PII-bearing dumps during "smoke" workflows.
  if (-not $env:POSTGRES_PASSWORD) {
    Load-EnvFile ".env"
    Load-EnvFile ".env.local"
  }
  if (-not $env:POSTGRES_PASSWORD) {
    $secret = Read-TextFile "secrets/db_password.txt"
    if ($secret) { $env:POSTGRES_PASSWORD = $secret }
  }
  if (-not $env:POSTGRES_PASSWORD) {
    throw "Cannot create backup: missing POSTGRES_PASSWORD (env or secrets/db_password.txt)."
  }

  $db = $env:POSTGRES_DB; if (-not $db) { $db = "hos" }
  $user = $env:POSTGRES_USER; if (-not $user) { $user = "hos" }

  $ts = Get-Date -Format "yyyyMMdd-HHmmss"
  # NOTE: PowerShell 5.1 doesn't support the ternary operator (?:). Keep this PS5-compatible.
  if ($IncludeData) { $suffix = "data" } else { $suffix = "schema" }
  $InFile = Join-Path $OutDir "hos-restore-smoke-$ts.$suffix.sql"
  Write-Host "Creating backup for smoke test -> $InFile"
  $createdDump = $true
  if ($IncludeData) {
    Write-Host "WARNING: -IncludeData will dump table data and may include PII. Avoid sharing this file." -ForegroundColor Yellow
    & $docker compose exec -T -e PGPASSWORD=$env:POSTGRES_PASSWORD db pg_dump -U $user -d $db > $InFile
  } else {
    & $docker compose exec -T -e PGPASSWORD=$env:POSTGRES_PASSWORD db pg_dump --schema-only --no-owner --no-privileges -U $user -d $db > $InFile
  }
  Write-Host "Backup OK."
}

if (-not (Test-Path $InFile)) { throw "File not found: $InFile" }

# Best-effort warning if user supplied a file that appears to contain table data.
try {
  if (-not $IncludeData) {
    $hit = Select-String -Path $InFile -Pattern "COPY public\.users|COPY public\.tenants|COPY public\.audit_events" -SimpleMatch -Quiet
    if ($hit) {
      Write-Host "WARNING: Input dump appears to contain table data (COPY ...). Treat as PII-bearing and avoid sharing." -ForegroundColor Yellow
    }
  }
} catch {
  # ignore scan errors
}

# Restore into a temporary Postgres container + temporary Docker volume (does NOT touch your compose DB volume).
$name = "hos-restore-smoke-" + ([Guid]::NewGuid().ToString("N").Substring(0, 8))
$vol = "hos_restore_smoke_pg_" + ([Guid]::NewGuid().ToString("N").Substring(0, 8))
$pw = New-RandomHex 24

Write-Host "Starting temp postgres container: $name"
& $docker volume create $vol | Out-Null

try {
  & $docker run -d --name $name -e POSTGRES_DB=hos -e POSTGRES_USER=hos -e POSTGRES_PASSWORD=$pw -v "${vol}:/var/lib/postgresql/data" postgres:16-alpine | Out-Null

  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  $ready = $false
  while ((Get-Date) -lt $deadline) {
    # Readiness is a two-step check:
    # 1) server socket accepts connections (pg_isready)
    # 2) the target DB exists and accepts a real query (psql)
    # NOTE: During early init, these commands may write to stderr and PowerShell (with $ErrorActionPreference=Stop)
    # would treat that as a terminating error. We intentionally swallow and retry.
    $serverReady = $false
    try {
      & $docker exec $name pg_isready -U hos -d postgres 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { $serverReady = $true }
    } catch {}

    if ($serverReady) {
      try {
        & $docker exec -e PGPASSWORD=$pw $name psql -U hos -d hos -tAc "select 1" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
      } catch {}
    }
    Start-Sleep -Seconds 2
  }
  if (-not $ready) { throw "Temp postgres did not become ready in ${TimeoutSec}s" }

  # Restore
  Write-Host "Restoring into temp DB..."
  Get-Content $InFile | & $docker exec -i -e PGPASSWORD=$pw $name psql -U hos -d hos | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "psql restore failed (exit $LASTEXITCODE)" }

  # Proof checks
  Write-Host "Verifying tables exist..."
  $check = "select (to_regclass('public.tenants') is not null) as tenants, (to_regclass('public.users') is not null) as users, (to_regclass('public.refresh_tokens') is not null) as refresh_tokens, (to_regclass('public.schema_migrations') is not null) as schema_migrations;"
  $out = & $docker exec -e PGPASSWORD=$pw $name psql -U hos -d hos -tAc "$check"
  if ($LASTEXITCODE -ne 0) { throw "psql table check failed (exit $LASTEXITCODE)" }
  $out = ($out | Out-String).Trim()
  Write-Host "table_check: $out"
  $cols = $out.Split("|")
  if ($cols.Count -ne 4 -or ($cols | Where-Object { $_.Trim() -ne "t" }).Count -gt 0) {
    throw "Table verification failed: $out"
  }

  $mCount = & $docker exec -e PGPASSWORD=$pw $name psql -U hos -d hos -tAc "select count(*) from schema_migrations;"
  if ($LASTEXITCODE -ne 0) { throw "psql schema_migrations count failed (exit $LASTEXITCODE)" }
  $mCount = ($mCount | Out-String).Trim()
  Write-Host "schema_migrations count: $mCount"

  Write-Host "OK: restore smoke passed."
  $success = $true
} catch {
  Write-Host "ERROR: restore smoke failed: $($_.Exception.Message)" -ForegroundColor Red
  try { & $docker logs --tail 200 $name } catch {}
  throw
} finally {
  try { & $docker rm -f $name | Out-Null } catch {}
  try { & $docker volume rm $vol | Out-Null } catch {}

  # Hygiene: avoid leaving dumps behind by default (repo zips/shares are a common leakage path).
  # Only delete dumps that this script created, and only on success (keep for debugging on failure).
  if ($createdDump -and $success -and (-not $KeepDump)) {
    try {
      Remove-Item -Force $InFile
      Write-Host "Cleanup: removed generated dump ($InFile). Use -KeepDump to keep it." -ForegroundColor DarkGray
    } catch {
      Write-Host "WARNING: could not remove generated dump ($InFile): $($_.Exception.Message)" -ForegroundColor Yellow
    }
  } elseif ($createdDump -and (-not $success) -and (-not $KeepDump)) {
    Write-Host "NOTE: generated dump kept for debugging: $InFile (use -KeepDump to suppress cleanup even on success)." -ForegroundColor DarkGray
  }
}


