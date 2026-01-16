# ops_output.ps1 - Shared Output Helper
# Provides consistent ASCII-only output functions for ops scripts
# PowerShell 5.1 compatible

# Initialize output encoding (UTF-8 without BOM, ASCII markers)
function Initialize-OpsOutput {
    # Ensure UTF-8 output without BOM for PowerShell 5.1
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
    # ASCII-only markers (no Unicode glyphs)
    $script:OutputInitialized = $true
}

# Write-Pass: Success message (ASCII marker: [PASS])
function Write-Pass {
    param([string]$Message)
    if ($OutputInitialized) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    }
}

# Write-Warn: Warning message (ASCII marker: [WARN])
function Write-Warn {
    param([string]$Message)
    if ($OutputInitialized) {
        Write-Host "[WARN] $Message" -ForegroundColor Yellow
    } else {
        Write-Host "[WARN] $Message" -ForegroundColor Yellow
    }
}

# Write-Fail: Failure message (ASCII marker: [FAIL])
function Write-Fail {
    param([string]$Message)
    if ($OutputInitialized) {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
    }
}

# Write-Info: Informational message (ASCII marker: [INFO])
function Write-Info {
    param([string]$Message)
    if ($OutputInitialized) {
        Write-Host "[INFO] $Message" -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] $Message" -ForegroundColor Cyan
    }
}

# Write-OpsTableRow: Format a single table row for ops_status output (ASCII-only)
# Ensures consistent table formatting across all ops_status runs
function Write-OpsTableRow {
    param(
        [string]$Check,
        [string]$Status,
        [int]$ExitCode,
        [string]$Notes
    )
    
    # Ensure ASCII-only (no Unicode)
    $statusMarker = switch ($Status) {
        "PASS" { "[PASS]" }
        "WARN" { "[WARN]" }
        "FAIL" { "[FAIL]" }
        "SKIP" { "[SKIP]" }
        default { "[$Status]" }
    }
    
    # Truncate long notes for table readability
    if ($Notes.Length -gt 80) {
        $Notes = $Notes.Substring(0, 77) + "..."
    }
    
    # Format: Check (padded to 40 chars) | Status (padded to 8) | ExitCode (padded to 8) | Notes
    $checkPadded = $Check.PadRight(40)
    $statusPadded = $statusMarker.PadRight(8)
    $exitCodePadded = $ExitCode.ToString().PadRight(8)
    
    Write-Host "$checkPadded $statusPadded $exitCodePadded $Notes" -NoNewline
    
    # Color code based on status
    switch ($Status) {
        "PASS" { Write-Host "" -ForegroundColor Green }
        "WARN" { Write-Host "" -ForegroundColor Yellow }
        "FAIL" { Write-Host "" -ForegroundColor Red }
        "SKIP" { Write-Host "" -ForegroundColor Gray }
        default { Write-Host "" }
    }
}
