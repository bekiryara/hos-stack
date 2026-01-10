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
