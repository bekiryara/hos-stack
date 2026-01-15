# core_availability.ps1 - Core Availability Probe
# Checks if core runtime dependencies (H-OS API + hos-db) are available
# PowerShell 5.1 compatible, ASCII-only output

# Probe result structure
$script:CoreAvailabilityResult = $null

# Test-CoreAvailability: Probe H-OS health + hos-db reachability
# Returns: @{ Available = $bool; Reason = "string"; Details = @{ HosHealth = $bool; HosDb = $bool } }
function Test-CoreAvailability {
    param(
        [int]$TimeoutSec = 5
    )
    
    $hosHealthOk = $false
    $hosDbOk = $false
    $reason = ""
    $details = @{
        HosHealth = $false
        HosDb = $false
    }
    
    # Check 1: H-OS /v1/health endpoint
    try {
        $hosResponse = Invoke-WebRequest -Uri "http://localhost:3000/v1/health" -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        if ($hosResponse.StatusCode -eq 200) {
            $hosBody = $hosResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($hosBody -and $hosBody.ok -eq $true) {
                $hosHealthOk = $true
                $details.HosHealth = $true
            } else {
                $reason = "H-OS health endpoint returned ok:false"
            }
        } else {
            $reason = "H-OS health endpoint returned HTTP $($hosResponse.StatusCode)"
        }
    } catch {
        $reason = "H-OS health endpoint unreachable: $($_.Exception.Message)"
    }
    
    # Check 2: hos-db container reachability
    try {
        # Check if hos-db container exists and is running
        $hosDbContainerNames = docker ps --format "{{.Names}}" | Select-String -Pattern "hos-db|hos_db"
        if ($hosDbContainerNames) {
            $hosDbContainerName = ($hosDbContainerNames | Select-Object -First 1).Line
            # Try to connect to database (simple pg_isready check)
            $dbCheck = docker exec $hosDbContainerName pg_isready -U postgres 2>&1
            if ($LASTEXITCODE -eq 0 -or ($dbCheck -match "accepting connections")) {
                $hosDbOk = $true
                $details.HosDb = $true
            } else {
                if (-not $hosHealthOk) {
                    $reason = "hos-db container not accepting connections"
                }
            }
        } else {
            if (-not $hosHealthOk) {
                $reason = "hos-db container not running"
            }
        }
    } catch {
        if (-not $hosHealthOk) {
            if ($reason) {
                $reason += "; hos-db check failed: $($_.Exception.Message)"
            } else {
                $reason = "hos-db check failed: $($_.Exception.Message)"
            }
        }
    }
    
    # Core is available if both checks pass
    $available = $hosHealthOk -and $hosDbOk
    
    # If H-OS health fails, that's the primary reason
    if (-not $hosHealthOk) {
        if (-not $reason) {
            $reason = "H-OS health endpoint unreachable"
        }
    } elseif (-not $hosDbOk) {
        if (-not $reason) {
            $reason = "hos-db container not reachable"
        }
    } else {
        $reason = "Core available"
    }
    
    $script:CoreAvailabilityResult = @{
        Available = $available
        Reason = $reason
        Details = $details
    }
    
    return $script:CoreAvailabilityResult
}

# Get-CoreAvailability: Get cached result or probe fresh
function Get-CoreAvailability {
    param(
        [switch]$Force
    )
    
    if ($Force -or $null -eq $script:CoreAvailabilityResult) {
        return Test-CoreAvailability
    }
    
    return $script:CoreAvailabilityResult
}

