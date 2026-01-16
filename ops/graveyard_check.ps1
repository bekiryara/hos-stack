# graveyard_check.ps1 - Enforce _graveyard/ policy

$ErrorActionPreference = "Stop"

# Load safe exit helper if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

function Invoke-SafeExit {
    param([int]$Code)
    if (Get-Command Invoke-OpsExit -ErrorAction SilentlyContinue) {
        Invoke-OpsExit $Code
    } else {
        exit $Code
    }
}

Write-Host "=== Graveyard Policy Check ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "_graveyard")) {
    Write-Host "PASS: _graveyard/ directory does not exist (nothing to check)" -ForegroundColor Green
    Invoke-SafeExit 0
}

$violations = @()

# Get all files in _graveyard (excluding POLICY.md and README.md)
$graveyardFiles = Get-ChildItem -Path "_graveyard" -Recurse -File | Where-Object {
    $_.Name -ne "POLICY.md" -and $_.Name -ne "README.md" -and $_.Name -notmatch "\.NOTE\.md$"
}

foreach ($file in $graveyardFiles) {
    $filePath = $file.FullName
    $relativePath = $filePath.Replace((Get-Location).Path + "\", "").Replace("\", "/")
    
    # Check if file has a corresponding note file
    $noteFile = $filePath + ".NOTE.md"
    $noteFileExists = Test-Path $noteFile
    
    # Check if file is mentioned in POLICY.md
    $policyMentioned = $false
    if (Test-Path "_graveyard/POLICY.md") {
        $policyContent = Get-Content "_graveyard/POLICY.md" -Raw
        $fileName = $file.Name
        if ($policyContent -match [regex]::Escape($fileName)) {
            $policyMentioned = $true
        }
    }
    
    # Check if this file was modified in the current commit/PR
    $isModified = $false
    try {
        # Check git diff for this file
        $gitDiff = git diff HEAD --name-only -- "$relativePath" 2>&1
        if ($gitDiff) {
            $isModified = $true
        }
        
        # Also check staged changes
        $gitStaged = git diff --cached --name-only -- "$relativePath" 2>&1
        if ($gitStaged) {
            $isModified = $true
        }
    } catch {
        # If git commands fail, assume not modified (safer)
        $isModified = $false
    }
    
    # If file was modified but has no note, it's a violation
    if ($isModified -and -not $noteFileExists -and -not $policyMentioned) {
        $violations += [PSCustomObject]@{
            File = $relativePath
            Issue = "Modified without note file or POLICY.md entry"
        }
    }
}

# Check for files moved to graveyard without notes
try {
    $movedFiles = git diff --name-status HEAD | Where-Object { $_ -match "^A\s+_graveyard/" }
    foreach ($move in $movedFiles) {
        if ($move -match "^A\s+(_graveyard/[^\s]+)$") {
            $newPath = $matches[1]
            $notePath = $newPath + ".NOTE.md"
            
            # Check if note exists
            if (-not (Test-Path $notePath)) {
                # Check if mentioned in POLICY.md
                $policyUpdated = $false
                $policyDiff = git diff HEAD "_graveyard/POLICY.md" 2>&1
                if ($policyDiff -and $policyDiff -match [regex]::Escape($newPath)) {
                    $policyUpdated = $true
                }
                
                if (-not $policyUpdated) {
                    $violations += [PSCustomObject]@{
                        File = $newPath
                        Issue = "Moved to graveyard without note file or POLICY.md entry"
                    }
                }
            }
        }
    }
} catch {
    # Git command may fail in some contexts, skip this check
    Write-Host "INFO: Could not check for moved files (git diff may not be available)" -ForegroundColor Yellow
}

# Report results
if ($violations.Count -gt 0) {
    Write-Host "FAIL: Graveyard policy violations found:" -ForegroundColor Red
    Write-Host ""
    foreach ($violation in $violations) {
        Write-Host "  - $($violation.File)" -ForegroundColor Yellow
        Write-Host "    Issue: $($violation.Issue)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Remediation:" -ForegroundColor Yellow
    Write-Host "  1. Create a .NOTE.md file alongside the moved/modified file" -ForegroundColor Gray
    Write-Host "  2. Or update _graveyard/POLICY.md with an entry for the file" -ForegroundColor Gray
    Write-Host "  3. Commit the note file or POLICY.md update together with the change" -ForegroundColor Gray
    Write-Host ""
    Invoke-SafeExit 1
} else {
    Write-Host "PASS: All graveyard files comply with policy" -ForegroundColor Green
    Invoke-SafeExit 0
}






