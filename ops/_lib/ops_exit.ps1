# ops_exit.ps1 - Safe Exit Helper for Ops Scripts
# Prevents terminal closure in interactive mode while preserving exit codes in CI
# PowerShell 5.1 compatible

function Initialize-OpsExit {
    <#
    .SYNOPSIS
    Initializes the ops exit helper (no-op, reserved for future use).
    
    .DESCRIPTION
    This function is provided for future extensibility. Currently performs no operation.
    #>
    # No-op for now, reserved for future initialization logic
}

function Invoke-OpsExit {
    <#
    .SYNOPSIS
    Safely exits with the specified exit code.
    
    .DESCRIPTION
    In CI environments (GitHub Actions, etc.), this function will call exit with the provided code.
    In interactive PowerShell sessions, it sets $global:LASTEXITCODE and returns to prevent terminal closure.
    
    .PARAMETER Code
    The exit code to return (0 = PASS, 1 = FAIL, 2 = WARN, etc.)
    
    .EXAMPLE
    Invoke-OpsExit 0
    # Sets exit code to 0 (PASS) without closing terminal in interactive mode
    
    .EXAMPLE
    Invoke-OpsExit 1
    # Sets exit code to 1 (FAIL) without closing terminal in interactive mode
    # In CI, this will exit with code 1
    #>
    param(
        [int]$Code
    )
    
    # Detect CI environment
    $isCI = ($env:CI -eq 'true') -or ($env:GITHUB_ACTIONS -eq 'true')
    
    if ($isCI) {
        # In CI, use hard exit (required for proper exit code propagation)
        exit $Code
    } else {
        # In interactive mode, set exit code but don't close terminal
        $global:LASTEXITCODE = $Code
        return
    }
}









