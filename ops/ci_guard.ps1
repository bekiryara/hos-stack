# ci_guard.ps1 - CI drift guard (forbidden files, secrets, non-ASCII paths)

param(
    [switch]$Quiet
)

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

if (-not $Quiet) {
    Write-Host "=== CI Guard (Drift Detection) ===" -ForegroundColor Cyan
    Write-Host ""
}

$hasFail = $false
$hasWarn = $false

# 1) Forbidden root artifacts
if (-not $Quiet) {
    Write-Host "[1] Checking for forbidden root artifacts..." -ForegroundColor Yellow
}
$forbiddenPatterns = @("*.zip", "*.rar", "*.bak", "*.tmp", "*.orig", "*.swp", "*~")
$foundForbidden = @()

foreach ($pattern in $forbiddenPatterns) {
    $files = Get-ChildItem -Path . -Filter $pattern -File -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.FullName -notmatch "\\_archive\\" -and 
            $_.FullName -notmatch "\\_graveyard\\" -and 
            $_.FullName -notmatch "\\vendor\\" -and 
            $_.FullName -notmatch "\\.git\\" 
        }
    if ($files) {
        $foundForbidden += $files
    }
}

if ($foundForbidden.Count -gt 0) {
    Write-Host "  [FAIL] Forbidden artifacts found in root:" -ForegroundColor Red
    $foundForbidden | ForEach-Object { Write-Host "    $($_.FullName)" -ForegroundColor Red }
    $hasFail = $true
} else {
    if (-not $Quiet) {
        Write-Host "  [PASS] No forbidden root artifacts" -ForegroundColor Green
    }
}

# 2) Dump/export files outside _archive/_graveyard
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[2] Checking for dump/export files outside archive..." -ForegroundColor Yellow
}
$dumpPatterns = @("*dump*", "*export*", "*backup*", "*.sql", "*.dump")
$foundDumps = @()

foreach ($pattern in $dumpPatterns) {
    $files = Get-ChildItem -Path . -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.FullName -notmatch "\\_archive\\" -and 
            $_.FullName -notmatch "\\_graveyard\\" -and 
            $_.FullName -notmatch "\\vendor\\" -and 
            $_.FullName -notmatch "\\.git\\" -and
            $_.FullName -notmatch "\\work\\pazar\\database\\" -and
            $_.FullName -notmatch "\\work\\hos\\database\\" -and
            $_.FullName -notmatch "\\migrations\\" -and
            $_.FullName -notmatch "\\ops\\snapshots\\" -and
            $_.FullName -notmatch "\\backup\\.ps1$" -and
            $_.FullName -notmatch "\\export.*\\.ps1$"
        }
    if ($files) {
        $foundDumps += $files
    }
}

if ($foundDumps.Count -gt 0) {
    Write-Host "  [WARN] Dump/export files found outside archive:" -ForegroundColor Yellow
    $foundDumps | Select-Object -First 10 | ForEach-Object { Write-Host "    $($_.FullName)" -ForegroundColor Yellow }
    if ($foundDumps.Count -gt 10) {
        Write-Host "    ... and $($foundDumps.Count - 10) more" -ForegroundColor Yellow
    }
    Write-Host "  Consider moving to _archive/ or _graveyard/" -ForegroundColor Yellow
    $hasWarn = $true
} else {
    if (-not $Quiet) {
        Write-Host "  [PASS] No dump/export files outside archive" -ForegroundColor Green
    }
}

# 3) Tracked secrets
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[3] Checking for tracked secrets..." -ForegroundColor Yellow
}
$secretPatterns = @(
    "work/hos/secrets/*.txt",
    ".env"
)
$foundSecrets = @()

try {
    foreach ($pattern in $secretPatterns) {
        $tracked = git ls-files $pattern 2>&1 | Where-Object { $_ -and $_ -notmatch "^fatal:" }
        if ($tracked) {
            # Filter out example files
            $realSecrets = $tracked | Where-Object { 
                $_ -notmatch "example" -and 
                $_ -notmatch "template" -and
                $_ -notmatch "\.example\." -and
                $_ -notmatch "\.template\."
            }
            if ($realSecrets) {
                $foundSecrets += $realSecrets
            }
        }
    }
    
    # Check for .key and .pem files (but exclude vendor)
    $keyFiles = git ls-files "*.key" 2>&1 | Where-Object { $_ -and $_ -notmatch "^fatal:" -and $_ -notmatch "\\vendor\\" }
    $pemFiles = git ls-files "*.pem" 2>&1 | Where-Object { $_ -and $_ -notmatch "^fatal:" -and $_ -notmatch "\\vendor\\" }
    if ($keyFiles) { $foundSecrets += $keyFiles }
    if ($pemFiles) { $foundSecrets += $pemFiles }
} catch {
    # Git might not be available, skip
}

if ($foundSecrets.Count -gt 0) {
    Write-Host "  [FAIL] Tracked secret files found:" -ForegroundColor Red
    $foundSecrets | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Write-Host "  Remove from git and add to .gitignore" -ForegroundColor Red
    $hasFail = $true
} else {
    if (-not $Quiet) {
        Write-Host "  [PASS] No tracked secrets" -ForegroundColor Green
    }
}

# 4) Non-ASCII paths
if (-not $Quiet) {
    Write-Host ""
    Write-Host "[4] Checking for non-ASCII file/folder names..." -ForegroundColor Yellow
}
$nonAsciiPaths = @()

try {
    $allFiles = git ls-files 2>&1 | Where-Object { $_ -and $_ -notmatch "^fatal:" }
    foreach ($file in $allFiles) {
        # Check if path contains non-ASCII characters
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($file)
        $hasNonAscii = $false
        foreach ($byte in $bytes) {
            if ($byte -gt 127) {
                $hasNonAscii = $true
                break
            }
        }
        if ($hasNonAscii) {
            $nonAsciiPaths += $file
        }
    }
} catch {
    # Git might not be available, skip
}

if ($nonAsciiPaths.Count -gt 0) {
    Write-Host "  [FAIL] Non-ASCII file/folder names found:" -ForegroundColor Red
    $nonAsciiPaths | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    if ($nonAsciiPaths.Count -gt 10) {
        Write-Host "    ... and $($nonAsciiPaths.Count - 10) more" -ForegroundColor Red
    }
    Write-Host "  Use ASCII-only names for compatibility" -ForegroundColor Red
    $hasFail = $true
} else {
    if (-not $Quiet) {
        Write-Host "  [PASS] All paths are ASCII" -ForegroundColor Green
    }
}

# Summary
if (-not $Quiet) {
    Write-Host ""
}

if ($hasFail) {
    Write-Host "=== CI GUARD: FAIL ===" -ForegroundColor Red
    Invoke-SafeExit 1
} elseif ($hasWarn) {
    Write-Host "=== CI GUARD: WARN ===" -ForegroundColor Yellow
    Invoke-SafeExit 2
} else {
    if (-not $Quiet) {
        Write-Host "=== CI GUARD: PASS ===" -ForegroundColor Green
    }
    Invoke-SafeExit 0
}

