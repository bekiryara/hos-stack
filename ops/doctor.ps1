#!/usr/bin/env pwsh
# Repository Health Doctor Script
# Comprehensive diagnostics for repository health

$ErrorActionPreference = "Continue"

Write-Host "=== REPOSITORY DOCTOR ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$results = @()
$hasFailures = $false

# 1. Docker Compose Services Status
Write-Host "[1] Checking Docker Compose services..." -ForegroundColor Yellow
try {
    $composeStatus = docker compose ps --format json 2>&1 | ConvertFrom-Json
    $allUp = $true
    foreach ($service in $composeStatus) {
        $isUp = $service.State -eq "running" -or $service.State -eq "Up"
        $allUp = $allUp -and $isUp
    }
    if ($allUp) {
        $results += @{
            Check = "Docker Compose Services"
            Status = "PASS"
            Details = "All services running"
        }
    } else {
        $results += @{
            Check = "Docker Compose Services"
            Status = "FAIL"
            Details = "One or more services not running"
        }
        $hasFailures = $true
    }
} catch {
    $results += @{
        Check = "Docker Compose Services"
        Status = "FAIL"
        Details = "Error: $($_.Exception.Message)"
    }
    $hasFailures = $true
}

Write-Host ""

# 2. H-OS Health Endpoint
Write-Host "[2] Checking H-OS health endpoint..." -ForegroundColor Yellow
try {
    $hosResponse = Invoke-WebRequest -Uri "http://localhost:3000/v1/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($hosResponse.StatusCode -eq 200) {
        $hosBody = $hosResponse.Content | ConvertFrom-Json
        if ($hosBody.ok -eq $true) {
            $results += @{
                Check = "H-OS Health (/v1/health)"
                Status = "PASS"
                Details = "HTTP 200, ok:true"
            }
        } else {
            $results += @{
                Check = "H-OS Health (/v1/health)"
                Status = "FAIL"
                Details = "HTTP 200 but ok != true"
            }
            $hasFailures = $true
        }
    } else {
        $results += @{
            Check = "H-OS Health (/v1/health)"
            Status = "FAIL"
            Details = "HTTP $($hosResponse.StatusCode)"
        }
        $hasFailures = $true
    }
} catch {
    $results += @{
        Check = "H-OS Health (/v1/health)"
        Status = "WARN"
        Details = "Not accessible: $($_.Exception.Message)"
    }
}

Write-Host ""

# 3. Pazar Up Endpoint
Write-Host "[3] Checking Pazar up endpoint..." -ForegroundColor Yellow
try {
    $pazarResponse = Invoke-WebRequest -Uri "http://localhost:8080/up" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($pazarResponse.StatusCode -eq 200) {
        $results += @{
            Check = "Pazar Up (/up)"
            Status = "PASS"
            Details = "HTTP 200"
        }
    } else {
        $results += @{
            Check = "Pazar Up (/up)"
            Status = "FAIL"
            Details = "HTTP $($pazarResponse.StatusCode)"
        }
        $hasFailures = $true
    }
} catch {
    $results += @{
        Check = "Pazar Up (/up)"
        Status = "WARN"
        Details = "Not accessible: $($_.Exception.Message)"
    }
}

Write-Host ""

# 4. Check Tracked Secrets
Write-Host "[4] Checking for tracked secrets..." -ForegroundColor Yellow
$trackedSecrets = git ls-files | Select-String -Pattern "secrets/|\.env$" -CaseSensitive:$false
if ($trackedSecrets) {
    $secretList = ($trackedSecrets | ForEach-Object { $_.Line }) -join ", "
    $results += @{
        Check = "Tracked Secrets"
        Status = "FAIL"
        Details = "Found: $secretList"
    }
    $hasFailures = $true
} else {
    $results += @{
        Check = "Tracked Secrets"
        Status = "PASS"
        Details = "No secrets/*.txt or .env files tracked"
    }
}

Write-Host ""

# 5. Check Forbidden Root Artifacts
Write-Host "[5] Checking for forbidden root artifacts..." -ForegroundColor Yellow
$forbiddenPatterns = @("*.zip", "*.rar", "*.bak", "*.tmp")
$foundArtifacts = @()
foreach ($pattern in $forbiddenPatterns) {
    $matches = Get-ChildItem -Path . -Filter $pattern -File -ErrorAction SilentlyContinue
    if ($matches) {
        $foundArtifacts += $matches.Name
    }
}
if ($foundArtifacts.Count -gt 0) {
    $artifactList = $foundArtifacts -join ", "
    $results += @{
        Check = "Forbidden Root Artifacts"
        Status = "FAIL"
        Details = "Found: $artifactList"
    }
    $hasFailures = $true
} else {
    $results += @{
        Check = "Forbidden Root Artifacts"
        Status = "PASS"
        Details = "No *.zip, *.rar, *.bak, *.tmp files in root"
    }
}

Write-Host ""

# 6. Check Snapshot Files
Write-Host "[6] Checking snapshot files..." -ForegroundColor Yellow
$requiredSnapshots = @(
    "ops/snapshots/routes.pazar.json",
    "ops/snapshots/schema.pazar.sql"
)
$missingSnapshots = @()
foreach ($snapshot in $requiredSnapshots) {
    if (-not (Test-Path $snapshot)) {
        $missingSnapshots += $snapshot
    }
}
if ($missingSnapshots.Count -gt 0) {
    $missingList = $missingSnapshots -join ", "
    $results += @{
        Check = "Snapshot Files"
        Status = "FAIL"
        Details = "Missing: $missingList"
    }
    $hasFailures = $true
} else {
    $results += @{
        Check = "Snapshot Files"
        Status = "PASS"
        Details = "All required snapshots present"
    }
}

Write-Host ""

# Summary Table
Write-Host "=== DOCTOR SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-40} {1,-10} {2}" -f "Check", "Status", "Details")
Write-Host ("-" * 80)
foreach ($result in $results) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "Gray" }
    }
    Write-Host ("{0,-40} {1,-10} {2}" -f $result.Check, $result.Status, $result.Details) -ForegroundColor $color
}

Write-Host ""

# Next Steps
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" } | Measure-Object).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" } | Measure-Object).Count

if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Review failures above" -ForegroundColor Gray
    Write-Host "  2. Run .\ops\triage.ps1 for detailed diagnostics" -ForegroundColor Gray
    Write-Host "  3. Fix issues before committing" -ForegroundColor Gray
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: Some checks returned warnings (services may be down)" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    exit 0
}

