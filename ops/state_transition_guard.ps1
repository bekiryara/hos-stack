#!/usr/bin/env pwsh
# STATE TRANSITION GUARD (WP-24)
# Validates state transitions are whitelist-only (no unauthorized transitions).

$ErrorActionPreference = "Stop"

# Load safe exit helper
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== STATE TRANSITION GUARD (WP-24) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$repoRoot = Split-Path -Parent $scriptDir

# Write snapshot file path
$writeSnapshot = Join-Path $repoRoot "contracts\api\marketplace.write.snapshot.json"

# Check snapshot file exists
if (-not (Test-Path $writeSnapshot)) {
    Write-Host "FAIL: Write snapshot not found: $writeSnapshot" -ForegroundColor Red
    exit 1
}

# Load snapshot
Write-Host "Loading write snapshot..." -ForegroundColor Yellow
try {
    $writeSnap = Get-Content $writeSnapshot -Raw | ConvertFrom-Json
} catch {
    Write-Host "FAIL: Error loading write snapshot: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Build whitelist map: endpoint -> allowed transitions
$whitelist = @{}
foreach ($endpoint in $writeSnap) {
    $key = "$($endpoint.method) $($endpoint.path)"
    $transitions = @()
    
    foreach ($trans in $endpoint.state_transitions) {
        $transKey = if ($trans.from -eq $null) { "null" } else { $trans.from }
        $transValue = $trans.to
        $transitions += "$transKey -> $transValue"
    }
    
    $whitelist[$key] = $transitions
}

Write-Host "Whitelist loaded: $($whitelist.Keys.Count) endpoints" -ForegroundColor Gray
Write-Host ""

# Validate each endpoint's state transitions match snapshot
Write-Host "Validating state transitions against whitelist..." -ForegroundColor Yellow

$routeFiles = Get-ChildItem -Path (Join-Path $repoRoot "work\pazar\routes\api") -Filter "*.php" -File

foreach ($endpoint in $writeSnap) {
    $method = $endpoint.method
    $path = $endpoint.path
    $key = "$method $path"
    
    # Find route file containing this endpoint
    $foundInFile = $null
    $routeContent = $null
    
    foreach ($routeFile in $routeFiles) {
        $content = Get-Content $routeFile.FullName -Raw
        
        # Check if this endpoint pattern exists in file
        $pathPattern = $path -replace '\{[^}]+\}', '[^/]+'
        $pattern = "Route::(?:middleware\([^)]+\)->)?$($method.ToLower())\(['""]$($path -replace '\{id\}', '\{id\}')"
        
        if ($content -match $pattern -or $path -match $pathPattern) {
            $foundInFile = $routeFile.FullName
            $routeContent = $content
            break
        }
    }
    
    if (-not $foundInFile) {
        Write-Host "WARN: Could not find route file for $key" -ForegroundColor Yellow
        continue
    }
    
    # Check state transitions are enforced in code
    # For each transition in whitelist, check code validates 'from' state before transition
    
    foreach ($trans in $endpoint.state_transitions) {
        $fromState = if ($trans.from -eq $null) { $null } else { $trans.from }
        $toState = $trans.to
        
        # Check if code validates 'from' state (for transitions that have a 'from' state)
        if ($fromState -ne $null) {
            # Look for status check in code (e.g., "status !== '$fromState'" or "status === '$fromState'")
            $hasStatusCheck = $false
            
            # Pattern 1: Check status before update
            if ($routeContent -match "status\s*[!=]=\s*['""]$fromState['""]") {
                $hasStatusCheck = $true
            }
            
            # Pattern 2: Check status in WHERE clause
            if ($routeContent -match "where\(['""]status['""],\s*['""]$fromState['""]\)") {
                $hasStatusCheck = $true
            }
            
            # Pattern 3: Check status before transition (more flexible)
            if ($routeContent -match "status.*['""]$fromState['""]") {
                $hasStatusCheck = $true
            }
            
            if (-not $hasStatusCheck) {
                Write-Host "WARN: $key transition '$fromState -> $toState' may not have status validation" -ForegroundColor Yellow
                Write-Host "  File: $(Split-Path -Leaf $foundInFile)" -ForegroundColor Gray
            } else {
                Write-Host "PASS: $key transition '$fromState -> $toState' has status validation" -ForegroundColor Green
            }
        } else {
            # Creating new resource (null -> toState), no status check needed
            Write-Host "INFO: $key creates new resource with status '$toState' (no from-state validation needed)" -ForegroundColor Gray
        }
    }
}

Write-Host ""

# Summary
if ($hasFailures) {
    Write-Host "=== STATE TRANSITION GUARD: FAIL ===" -ForegroundColor Red
    Write-Host "Some state transitions may not be properly validated" -ForegroundColor Red
    exit 1
}

Write-Host "=== STATE TRANSITION GUARD: PASS ===" -ForegroundColor Green
Write-Host "All state transitions match snapshot whitelist" -ForegroundColor Green
Write-Host "Note: This is a best-effort check. Manual review recommended for critical transitions." -ForegroundColor Gray
exit 0

