# Repo Payload Guard (WP-53)
# Deterministic FAIL if any tracked file exceeds size budget OR matches forbidden patterns
# Exit code: 0 PASS, 1 FAIL

param(
    [int]$SizeBudgetBytes = 2097152  # Default 2MB
)

$ErrorActionPreference = "Stop"

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Print sanitized
function Write-Sanitized {
    param([string]$text, [string]$Color = "White")
    $sanitized = Sanitize-Ascii $text
    Write-Host $sanitized -ForegroundColor $Color
}

Write-Host "=== REPO PAYLOAD GUARD (WP-53) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Size Budget: $([math]::Round($SizeBudgetBytes / 1MB, 2)) MB" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false
$violations = @()

# Check 1: Tracked files exceeding size budget
Write-Host "[1] Checking tracked file sizes..." -ForegroundColor Yellow

try {
    $trackedFiles = git ls-files
    foreach ($file in $trackedFiles) {
        if (Test-Path $file) {
            $fileInfo = Get-Item $file -ErrorAction SilentlyContinue
            if ($fileInfo -and $fileInfo.Length -gt $SizeBudgetBytes) {
                $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                $violations += [PSCustomObject]@{
                    File = $file
                    Reason = "Size: $sizeMB MB (exceeds $([math]::Round($SizeBudgetBytes / 1MB, 2)) MB budget)"
                    Type = "Size"
                }
            }
        }
    }
    
    if ($violations.Count -eq 0) {
        Write-Host "PASS: No tracked files exceed size budget" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Found $($violations.Count) file(s) exceeding size budget" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Sanitized "ERROR: Failed to check file sizes: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

Write-Host ""

# Check 2: Forbidden generated patterns
Write-Host "[2] Checking forbidden generated patterns..." -ForegroundColor Yellow

$forbiddenPatterns = @(
    'dist/',
    'build/',
    '\.next/',
    'vendor/',
    'node_modules/',
    'coverage/',
    'logs/',
    'tmp/',
    '_archive/'
)

try {
    $trackedFiles = git ls-files
    foreach ($file in $trackedFiles) {
        foreach ($pattern in $forbiddenPatterns) {
            if ($file -match $pattern) {
                $violations += [PSCustomObject]@{
                    File = $file
                    Reason = "Matches forbidden pattern: $pattern"
                    Type = "Pattern"
                }
                break
            }
        }
    }
    
    $patternViolations = $violations | Where-Object { $_.Type -eq "Pattern" }
    if ($patternViolations.Count -eq 0) {
        Write-Host "PASS: No tracked files match forbidden patterns" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Found $($patternViolations.Count) file(s) matching forbidden patterns" -ForegroundColor Red
        $hasFailures = $true
    }
} catch {
    Write-Sanitized "ERROR: Failed to check forbidden patterns: $($_.Exception.Message)" "Red"
    $hasFailures = $true
}

Write-Host ""

# Check 3: Git count-objects (optional but deterministic)
Write-Host "[3] Checking git repository size..." -ForegroundColor Yellow

try {
    $countObjects = git count-objects -vH 2>&1
    $sizePack = $null
    foreach ($line in $countObjects) {
        if ($line -match 'size-pack:\s+(\d+\.?\d*)\s*([KMGT]?)') {
            $sizeValue = [double]$matches[1]
            $unit = $matches[2]
            
            # Convert to bytes
            $multiplier = switch ($unit) {
                'K' { 1024 }
                'M' { 1024 * 1024 }
                'G' { 1024 * 1024 * 1024 }
                'T' { 1024 * 1024 * 1024 * 1024 }
                default { 1 }
            }
            $sizePack = $sizeValue * $multiplier
            
            # Warn if repo is abnormally large (>100MB)
            if ($sizePack -gt 104857600) {  # 100MB
                $sizeMB = [math]::Round($sizePack / 1MB, 2)
                Write-Host "WARN: Repository pack size is $sizeMB MB (abnormally large)" -ForegroundColor Yellow
                Write-Host "  Consider running: git gc --aggressive" -ForegroundColor Gray
            } else {
                $sizeMB = [math]::Round($sizePack / 1MB, 2)
                Write-Host "PASS: Repository pack size: $sizeMB MB" -ForegroundColor Green
            }
            break
        }
    }
    
    if (-not $sizePack) {
        Write-Host "WARN: Could not determine repository pack size" -ForegroundColor Yellow
    }
} catch {
    Write-Sanitized "WARN: Failed to check git count-objects: $($_.Exception.Message)" "Yellow"
}

Write-Host ""

# Report violations
if ($violations.Count -gt 0) {
    Write-Host "=== VIOLATIONS DETECTED ===" -ForegroundColor Red
    Write-Host ""
    foreach ($v in $violations) {
        Write-Sanitized "File: $($v.File)" "Red"
        Write-Sanitized "  Reason: $($v.Reason)" "Yellow"
        Write-Host ""
    }
    
    Write-Host "=== REMEDIATION ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To fix violations:" -ForegroundColor White
    Write-Host "  1. Remove the file from git tracking: git rm --cached <file>" -ForegroundColor Gray
    Write-Host "  2. Add to .gitignore if needed" -ForegroundColor Gray
    Write-Host "  3. Recommit: git commit -m 'Remove large payload file'" -ForegroundColor Gray
    Write-Host ""
}

# Final result
if ($hasFailures) {
    Write-Host "=== REPO PAYLOAD GUARD: FAIL ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== REPO PAYLOAD GUARD: PASS ===" -ForegroundColor Green
    exit 0
}
