#!/usr/bin/env pwsh
# Incident Bundle Generator
# Collects system state and evidence for incident investigation

$ErrorActionPreference = "Continue"

# Generate timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundleDir = "_archive/incidents/incident-$timestamp"

Write-Host "=== INCIDENT BUNDLE GENERATOR ===" -ForegroundColor Cyan
Write-Host "Creating bundle: $bundleDir" -ForegroundColor Yellow

# Create directory
try {
    New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null
    Write-Host "✓ Directory created" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$filesCreated = @()

# 1. meta.txt
Write-Host "[1] Collecting metadata..." -ForegroundColor Yellow
$timestamp2 = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$gitBranch = git rev-parse --abbrev-ref HEAD 2>&1 | Out-String
$gitCommit = git rev-parse HEAD 2>&1 | Out-String
$gitStatus = git status --short 2>&1 | Select-Object -First 10 | Out-String
$metaContent = "Incident Bundle Generated: $timestamp2`nGit Branch: $gitBranch`nGit Commit: $gitCommit`nGit Status: $gitStatus"
$metaContent | Out-File -FilePath (Join-Path $bundleDir "meta.txt") -Encoding UTF8
$filesCreated += "meta.txt"
Write-Host "  ✓ meta.txt" -ForegroundColor Green

# 2. compose_ps.txt
Write-Host "[2] Collecting Docker Compose status..." -ForegroundColor Yellow
try {
    docker compose ps 2>&1 | Out-File -FilePath (Join-Path $bundleDir "compose_ps.txt") -Encoding UTF8
    $filesCreated += "compose_ps.txt"
    Write-Host "  ✓ compose_ps.txt" -ForegroundColor Green
} catch {
    "Error: $($_.Exception.Message)" | Out-File -FilePath (Join-Path $bundleDir "compose_ps.txt") -Encoding UTF8
    $filesCreated += "compose_ps.txt"
    Write-Host "  ⚠ compose_ps.txt (error captured)" -ForegroundColor Yellow
}

# 3. hos_health.txt
Write-Host "[3] Collecting H-OS health..." -ForegroundColor Yellow
try {
    $hosResponse = Invoke-WebRequest -Uri "http://localhost:3000/v1/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    "$($hosResponse.StatusCode)`n$($hosResponse.Content)" | Out-File -FilePath (Join-Path $bundleDir "hos_health.txt") -Encoding UTF8
    $filesCreated += "hos_health.txt"
    Write-Host "  ✓ hos_health.txt" -ForegroundColor Green
} catch {
    "Error: $($_.Exception.Message)" | Out-File -FilePath (Join-Path $bundleDir "hos_health.txt") -Encoding UTF8
    $filesCreated += "hos_health.txt"
    Write-Host "  ⚠ hos_health.txt (error captured)" -ForegroundColor Yellow
}

# 4. pazar_up.txt
Write-Host "[4] Collecting Pazar /up endpoint..." -ForegroundColor Yellow
try {
    $pazarResponse = Invoke-WebRequest -Uri "http://localhost:8080/up" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    "$($pazarResponse.StatusCode)`n$($pazarResponse.Headers | ConvertTo-Json)`n$($pazarResponse.Content)" | Out-File -FilePath (Join-Path $bundleDir "pazar_up.txt") -Encoding UTF8
    $filesCreated += "pazar_up.txt"
    Write-Host "  ✓ pazar_up.txt" -ForegroundColor Green
} catch {
    "Error: $($_.Exception.Message)" | Out-File -FilePath (Join-Path $bundleDir "pazar_up.txt") -Encoding UTF8
    $filesCreated += "pazar_up.txt"
    Write-Host "  ⚠ pazar_up.txt (error captured)" -ForegroundColor Yellow
}

# 5. pazar_routes_snapshot.txt
Write-Host "[5] Collecting routes snapshot..." -ForegroundColor Yellow
if (Test-Path "ops/snapshots/routes.pazar.json") {
    Copy-Item "ops/snapshots/routes.pazar.json" (Join-Path $bundleDir "pazar_routes_snapshot.txt")
    $filesCreated += "pazar_routes_snapshot.txt"
    Write-Host "  ✓ pazar_routes_snapshot.txt" -ForegroundColor Green
} else {
    "File not found: ops/snapshots/routes.pazar.json" | Out-File -FilePath (Join-Path $bundleDir "pazar_routes_snapshot.txt") -Encoding UTF8
    $filesCreated += "pazar_routes_snapshot.txt"
    Write-Host "  ⚠ pazar_routes_snapshot.txt (not found)" -ForegroundColor Yellow
}

# 6. pazar_schema_snapshot.txt
Write-Host "[6] Collecting schema snapshot..." -ForegroundColor Yellow
if (Test-Path "ops/snapshots/schema.pazar.sql") {
    Copy-Item "ops/snapshots/schema.pazar.sql" (Join-Path $bundleDir "pazar_schema_snapshot.txt")
    $filesCreated += "pazar_schema_snapshot.txt"
    Write-Host "  ✓ pazar_schema_snapshot.txt" -ForegroundColor Green
} else {
    "File not found: ops/snapshots/schema.pazar.sql" | Out-File -FilePath (Join-Path $bundleDir "pazar_schema_snapshot.txt") -Encoding UTF8
    $filesCreated += "pazar_schema_snapshot.txt"
    Write-Host "  ⚠ pazar_schema_snapshot.txt (not found)" -ForegroundColor Yellow
}

# 7. version.txt
Write-Host "[7] Collecting VERSION..." -ForegroundColor Yellow
if (Test-Path "VERSION") {
    Get-Content "VERSION" | Out-File -FilePath (Join-Path $bundleDir "version.txt") -Encoding UTF8
    $filesCreated += "version.txt"
    Write-Host "  ✓ version.txt" -ForegroundColor Green
} else {
    "File not found: VERSION" | Out-File -FilePath (Join-Path $bundleDir "version.txt") -Encoding UTF8
    $filesCreated += "version.txt"
    Write-Host "  ⚠ version.txt (not found)" -ForegroundColor Yellow
}

# 8. changelog_unreleased.txt
Write-Host "[8] Collecting CHANGELOG.md [Unreleased] section..." -ForegroundColor Yellow
if (Test-Path "CHANGELOG.md") {
    $changelogContent = Get-Content "CHANGELOG.md" -Raw
    if ($changelogContent -match '##\s*\[Unreleased\]\s*([\s\S]*?)(?=##\s*\[|\Z)') {
        $unreleasedSection = $matches[1]
        $unreleasedSection | Out-File -FilePath (Join-Path $bundleDir "changelog_unreleased.txt") -Encoding UTF8
    } else {
        # Fallback: copy full changelog
        $changelogContent | Out-File -FilePath (Join-Path $bundleDir "changelog_unreleased.txt") -Encoding UTF8
    }
    $filesCreated += "changelog_unreleased.txt"
    Write-Host "  ✓ changelog_unreleased.txt" -ForegroundColor Green
} else {
    "File not found: CHANGELOG.md" | Out-File -FilePath (Join-Path $bundleDir "changelog_unreleased.txt") -Encoding UTF8
    $filesCreated += "changelog_unreleased.txt"
    Write-Host "  ⚠ changelog_unreleased.txt (not found)" -ForegroundColor Yellow
}

# 9. logs_pazar_app.txt
Write-Host "[9] Collecting Pazar app logs (last 500 lines)..." -ForegroundColor Yellow
try {
    docker compose logs --tail 500 pazar-app 2>&1 | Out-File -FilePath (Join-Path $bundleDir "logs_pazar_app.txt") -Encoding UTF8
    $filesCreated += "logs_pazar_app.txt"
    Write-Host "  ✓ logs_pazar_app.txt" -ForegroundColor Green
} catch {
    "Error: $($_.Exception.Message)" | Out-File -FilePath (Join-Path $bundleDir "logs_pazar_app.txt") -Encoding UTF8
    $filesCreated += "logs_pazar_app.txt"
    Write-Host "  ⚠ logs_pazar_app.txt (error captured)" -ForegroundColor Yellow
}

# 10. logs_hos_api.txt
Write-Host "[10] Collecting H-OS API logs (last 500 lines)..." -ForegroundColor Yellow
try {
    docker compose logs --tail 500 hos-api 2>&1 | Out-File -FilePath (Join-Path $bundleDir "logs_hos_api.txt") -Encoding UTF8
    $filesCreated += "logs_hos_api.txt"
    Write-Host "  ✓ logs_hos_api.txt" -ForegroundColor Green
} catch {
    "Error: $($_.Exception.Message)" | Out-File -FilePath (Join-Path $bundleDir "logs_hos_api.txt") -Encoding UTF8
    $filesCreated += "logs_hos_api.txt"
    Write-Host "  ⚠ logs_hos_api.txt (error captured)" -ForegroundColor Yellow
}

# 11. incident_note.md (template)
Write-Host "[11] Generating incident_note.md template..." -ForegroundColor Yellow
$noteGenTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$noteTemplate = @'
# Incident Notes

**Generated**: {0}

## What happened?

(Describe the incident)

## When?

**Start Time**: (YYYY-MM-DD HH:mm:ss)
**Detection Time**: (YYYY-MM-DD HH:mm:ss)
**Resolution Time**: (YYYY-MM-DD HH:mm:ss, if resolved)

## Request ID(s)

(If applicable, list request_id(s) from error responses or logs)
- request_id_1
- request_id_2

## Steps Taken

1. (Step 1)
2. (Step 2)
3. (Step 3)

## Current Status

(SEV1 / SEV2 / SEV3)
**Severity**: (SEV level)
**Status**: (Investigating / Mitigated / Resolved)

## Additional Notes

(Any other relevant information)
'@ -f $noteGenTime
$noteTemplate | Out-File -FilePath (Join-Path $bundleDir "incident_note.md") -Encoding UTF8
$filesCreated += "incident_note.md"
Write-Host "  ✓ incident_note.md" -ForegroundColor Green

Write-Host ""
Write-Host "=== BUNDLE COMPLETE ===" -ForegroundColor Cyan
Write-Host "Bundle location: $bundleDir" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor Yellow
foreach ($file in $filesCreated) {
    Write-Host "  - $file" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review incident_note.md and fill in details" -ForegroundColor Gray
Write-Host "  2. Attach bundle folder to issue/PR (zip if needed)" -ForegroundColor Gray
Write-Host "  3. Reference bundle path in incident documentation" -ForegroundColor Gray

exit 0
