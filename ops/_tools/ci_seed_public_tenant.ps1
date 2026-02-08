param(
  [string]$TenantSlug = "public",
  [string]$TenantName = "Public",
  [int]$WaitSeconds = 60,
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Info([string]$msg) { if (-not $Quiet) { Write-Host "[ci_seed_public_tenant] $msg" -ForegroundColor Cyan } }
function Warn([string]$msg) { Write-Host "[ci_seed_public_tenant] WARN: $msg" -ForegroundColor Yellow }

Info "Seeding tenant slug='$TenantSlug' (idempotent)"

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$ready = $false

while ((Get-Date) -lt $deadline) {
  try {
    docker compose exec -T hos-db pg_isready -U hos -d hos | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  } catch {
    # ignore and retry
  }
  Start-Sleep -Seconds 2
}

if (-not $ready) {
  Warn "hos-db not ready after ${WaitSeconds}s; skipping seed"
  exit 0
}

# Use deterministic UUID so repeated seeds are stable.
$tenantId = "00000000-0000-0000-0000-000000000001"

$sql = @"
insert into tenants (id, slug, name)
values ('$tenantId', '$TenantSlug', '$TenantName')
on conflict (slug) do nothing;
"@

Info "Inserting tenant into hos-db..."
docker compose exec -T hos-db psql -U hos -d hos -v ON_ERROR_STOP=1 -c "$sql" | Out-Null

Info "OK"

