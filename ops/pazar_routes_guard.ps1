#!/usr/bin/env pwsh
# PAZAR ROUTES GUARDRAILS (WP-21)
# Enforces line-count budgets and prevents unreferenced module drift
# PowerShell 5.1 compatible, ASCII-only output

$ErrorActionPreference = "Stop"

Write-Host "=== PAZAR ROUTES GUARDRAILS (WP-21) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Locate repo root from script location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

# Verify paths exist
$apiEntryPoint = Join-Path $repoRoot "work\pazar\routes\api.php"
$apiModulesDir = Join-Path $repoRoot "work\pazar\routes\api"

if (-not (Test-Path $apiEntryPoint)) {
    Write-Host "FAIL: Entry point not found: $apiEntryPoint" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $apiModulesDir)) {
    Write-Host "FAIL: Modules directory not found: $apiModulesDir" -ForegroundColor Red
    exit 1
}

Write-Host "[1] Checking route duplicate guard..." -ForegroundColor Yellow
$duplicateGuardPath = Join-Path $scriptDir "route_duplicate_guard.ps1"
if (Test-Path $duplicateGuardPath) {
    try {
        & $duplicateGuardPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAIL: Route duplicate guard failed" -ForegroundColor Red
            exit 1
        }
        Write-Host "PASS: Route duplicate guard passed" -ForegroundColor Green
    } catch {
        Write-Host "FAIL: Route duplicate guard error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "WARN: Route duplicate guard not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[2] Parsing entry point for referenced modules..." -ForegroundColor Yellow
$apiContent = Get-Content $apiEntryPoint -Raw
$referencedModules = @()

# Extract require_once statements: require_once __DIR__.'/api/00_ping.php';
# Pattern matches: require_once __DIR__.'/api/FILENAME.php';
$pattern = "require_once\s+__DIR__\.'/api/([^']+\.php)'"
$matches = [regex]::Matches($apiContent, $pattern)

foreach ($match in $matches) {
    $moduleName = $match.Groups[1].Value
    $referencedModules += $moduleName
}

Write-Host "  Found $($referencedModules.Count) referenced modules" -ForegroundColor Gray
foreach ($module in $referencedModules) {
    Write-Host "    - $module" -ForegroundColor Gray
}
Write-Host ""

Write-Host "[3] Checking actual module files..." -ForegroundColor Yellow
$actualModules = @()
$moduleFiles = Get-ChildItem -Path $apiModulesDir -Filter "*.php" -File
foreach ($file in $moduleFiles) {
    $actualModules += $file.Name
}

Write-Host "  Found $($actualModules.Count) actual module files" -ForegroundColor Gray
Write-Host ""

# Check for missing referenced modules
Write-Host "[4] Checking for missing referenced modules..." -ForegroundColor Yellow
$missingModules = @()
foreach ($refModule in $referencedModules) {
    if (-not ($actualModules -contains $refModule)) {
        $missingModules += $refModule
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host "FAIL: Referenced modules missing on disk:" -ForegroundColor Red
    foreach ($missing in $missingModules) {
        Write-Host "  - $missing" -ForegroundColor Yellow
    }
    exit 1
}
Write-Host "PASS: All referenced modules exist" -ForegroundColor Green
Write-Host ""

# Check for unreferenced modules
Write-Host "[5] Checking for unreferenced modules..." -ForegroundColor Yellow
$unreferencedModules = @()
foreach ($actualModule in $actualModules) {
    if (-not ($referencedModules -contains $actualModule)) {
        $unreferencedModules += $actualModule
    }
}

if ($unreferencedModules.Count -gt 0) {
    Write-Host "FAIL: Unreferenced module files found (legacy drift):" -ForegroundColor Red
    foreach ($unref in $unreferencedModules) {
        Write-Host "  - $unref" -ForegroundColor Yellow
    }
    Write-Host "  These files are not required by api.php and should be removed or added to api.php" -ForegroundColor Gray
    exit 1
}
Write-Host "PASS: No unreferenced modules found" -ForegroundColor Green
Write-Host ""

# Enforce line-count budgets
Write-Host "[6] Checking line-count budgets..." -ForegroundColor Yellow
$hasBudgetViolations = $false

# Entry point budget: max 120 lines
$entryPointLines = (Get-Content $apiEntryPoint).Count
Write-Host "  Entry point (api.php): $entryPointLines lines (max: 120)" -ForegroundColor Gray
if ($entryPointLines -gt 120) {
    Write-Host "FAIL: Entry point exceeds budget: $entryPointLines > 120" -ForegroundColor Red
    $hasBudgetViolations = $true
}

# Module budgets: max 900 lines each
Write-Host "  Modules:" -ForegroundColor Gray
foreach ($refModule in $referencedModules) {
    $modulePath = Join-Path $apiModulesDir $refModule
    if (Test-Path $modulePath) {
        $moduleLines = (Get-Content $modulePath).Count
        Write-Host "    - $refModule : $moduleLines lines (max: 900)" -ForegroundColor Gray
        if ($moduleLines -gt 900) {
            Write-Host "FAIL: Module exceeds budget: $refModule ($moduleLines > 900)" -ForegroundColor Red
            $hasBudgetViolations = $true
        }
    }
}

if ($hasBudgetViolations) {
    Write-Host ""
    exit 1
}

Write-Host "PASS: All line-count budgets met" -ForegroundColor Green
Write-Host ""

Write-Host "=== PAZAR ROUTES GUARDRAILS: PASS ===" -ForegroundColor Green
exit 0

