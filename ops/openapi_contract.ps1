# openapi_contract.ps1 - OpenAPI Contract Check
# Validates OpenAPI spec exists, is valid, and matches implemented endpoints
# PowerShell 5.1 compatible, ASCII-only output, safe-exit behavior

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== OPENAPI CONTRACT CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()
$overallStatus = "PASS"
$overallExitCode = 0
$hasWarn = $false
$hasFail = $false

# Helper: Add check result
function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Notes,
        [bool]$Blocking = $true
    )
    
    $exitCode = 0
    if ($Status -eq "FAIL") {
        $exitCode = 1
        $script:hasFail = $true
        $script:overallStatus = "FAIL"
        $script:overallExitCode = 1
    } elseif ($Status -eq "WARN") {
        $exitCode = 2
        $script:hasWarn = $true
        if ($script:overallStatus -eq "PASS") {
            $script:overallStatus = "WARN"
            $script:overallExitCode = 2
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = $CheckName
        Status = $Status
        Notes = $Notes
        ExitCode = $exitCode
        Blocking = $Blocking
    }
}

# Check 1: File exists
Write-Host "Check 1: OpenAPI spec file exists" -ForegroundColor Cyan

$openApiPath = "docs\product\openapi.yaml"
if (-not (Test-Path $openApiPath)) {
    Add-CheckResult -CheckName "File exists" -Status "FAIL" -Notes "OpenAPI spec file not found: $openApiPath"
} else {
    Add-CheckResult -CheckName "File exists" -Status "PASS" -Notes "OpenAPI spec file found: $openApiPath"
}

Write-Host ""

# Check 2: YAML sanity (if file exists)
if (Test-Path $openApiPath) {
    Write-Host "Check 2: YAML structure validation" -ForegroundColor Cyan
    
    try {
        $content = Get-Content $openApiPath -Raw -Encoding UTF8
        
        # Check for required OpenAPI fields
        $hasOpenApi = $content -match "openapi\s*:"
        $hasPaths = $content -match "paths\s*:"
        $hasComponents = $content -match "components\s*:"
        $hasErrorEnvelope = $content -match "ErrorEnvelope" -or $content -match "errorEnvelope"
        $hasRequestId = $content -match "request_id" -or $content -match "requestId"
        
        if (-not $hasOpenApi) {
            Add-CheckResult -CheckName "YAML structure (openapi field)" -Status "FAIL" -Notes "Missing 'openapi:' field"
        } else {
            Add-CheckResult -CheckName "YAML structure (openapi field)" -Status "PASS" -Notes "Contains 'openapi:' field"
        }
        
        if (-not $hasPaths) {
            Add-CheckResult -CheckName "YAML structure (paths field)" -Status "FAIL" -Notes "Missing 'paths:' field"
        } else {
            Add-CheckResult -CheckName "YAML structure (paths field)" -Status "PASS" -Notes "Contains 'paths:' field"
        }
        
        if (-not $hasComponents) {
            Add-CheckResult -CheckName "YAML structure (components field)" -Status "FAIL" -Notes "Missing 'components:' field"
        } else {
            Add-CheckResult -CheckName "YAML structure (components field)" -Status "PASS" -Notes "Contains 'components:' field"
        }
        
        if (-not $hasErrorEnvelope) {
            Add-CheckResult -CheckName "YAML structure (ErrorEnvelope schema)" -Status "FAIL" -Notes "Missing ErrorEnvelope schema definition"
        } else {
            Add-CheckResult -CheckName "YAML structure (ErrorEnvelope schema)" -Status "PASS" -Notes "Contains ErrorEnvelope schema"
        }
        
        if (-not $hasRequestId) {
            Add-CheckResult -CheckName "YAML structure (request_id field)" -Status "FAIL" -Notes "Missing request_id field in ErrorEnvelope"
        } else {
            Add-CheckResult -CheckName "YAML structure (request_id field)" -Status "PASS" -Notes "Contains request_id field"
        }
    } catch {
        Add-CheckResult -CheckName "YAML structure (read error)" -Status "FAIL" -Notes "Failed to read OpenAPI file: $($_.Exception.Message)"
    }
    
    Write-Host ""
}

# Check 3: Write endpoints presence in OpenAPI
Write-Host "Check 3: Write endpoints in OpenAPI spec" -ForegroundColor Cyan

if (Test-Path $openApiPath) {
    try {
        $content = Get-Content $openApiPath -Raw -Encoding UTF8
        
        $enabledWorlds = @("commerce", "food", "rentals")
        $allWriteEndpointsFound = $true
        $missingEndpoints = @()
        
        foreach ($world in $enabledWorlds) {
            # Check POST /api/v1/{world}/listings
            # Simple pattern: look for post: after the path definition
            $hasPost = $content -match "/api/v1/${world}/listings" -and $content -match "`r?`n\s+post:"
            if (-not $hasPost) {
                $allWriteEndpointsFound = $false
                $missingEndpoints += "POST /api/v1/${world}/listings"
            }
            
            # Check PATCH /api/v1/{world}/listings/{id}
            $hasPatch = $content -match "/api/v1/${world}/listings/\{id\}" -and $content -match "`r?`n\s+patch:"
            if (-not $hasPatch) {
                $allWriteEndpointsFound = $false
                $missingEndpoints += "PATCH /api/v1/${world}/listings/{id}"
            }
            
            # Check DELETE /api/v1/{world}/listings/{id}
            $hasDelete = $content -match "/api/v1/${world}/listings/\{id\}" -and $content -match "`r?`n\s+delete:"
            if (-not $hasDelete) {
                $allWriteEndpointsFound = $false
                $missingEndpoints += "DELETE /api/v1/${world}/listings/{id}"
            }
        }
        
        if ($allWriteEndpointsFound) {
            Add-CheckResult -CheckName "Write endpoints in OpenAPI" -Status "PASS" -Notes "All write endpoints (POST/PATCH/DELETE) found for enabled worlds"
        } else {
            Add-CheckResult -CheckName "Write endpoints in OpenAPI" -Status "FAIL" -Notes "Missing write endpoints: $($missingEndpoints -join ', ')"
        }
    } catch {
        Add-CheckResult -CheckName "Write endpoints in OpenAPI" -Status "WARN" -Notes "Could not check write endpoints: $($_.Exception.Message)" -Blocking $false
    }
} else {
    Add-CheckResult -CheckName "Write endpoints in OpenAPI" -Status "WARN" -Notes "OpenAPI spec file not found" -Blocking $false
}

Write-Host ""

# Check 4: Drift guard vs implemented spine doc
Write-Host "Check 4: Documentation drift guard" -ForegroundColor Cyan

$spineDocPath = "docs\product\PRODUCT_API_SPINE.md"
if (Test-Path $spineDocPath) {
    try {
        $spineContent = Get-Content $spineDocPath -Raw -Encoding UTF8
        
        # Check if PRODUCT_API_SPINE.md references openapi.yaml
        $referencesOpenApi = $spineContent -match "openapi\.yaml" -or $spineContent -match "openapi" -or $spineContent -match "OpenAPI"
        
        if ($referencesOpenApi) {
            Add-CheckResult -CheckName "Documentation drift guard" -Status "PASS" -Notes "PRODUCT_API_SPINE.md references OpenAPI spec"
        } else {
            Add-CheckResult -CheckName "Documentation drift guard" -Status "WARN" -Notes "PRODUCT_API_SPINE.md should reference openapi.yaml as single source of truth" -Blocking $false
        }
    } catch {
        Add-CheckResult -CheckName "Documentation drift guard" -Status "WARN" -Notes "Could not read PRODUCT_API_SPINE.md: $($_.Exception.Message)" -Blocking $false
    }
} else {
    Add-CheckResult -CheckName "Documentation drift guard" -Status "WARN" -Notes "PRODUCT_API_SPINE.md not found" -Blocking $false
}

Write-Host ""

# Check 5: Optional endpoint probe (only if Docker stack reachable)
Write-Host "Check 5: Endpoint probe (optional)" -ForegroundColor Cyan

try {
    # Try to reach base URL
    $testResponse = $null
    try {
        $testResponse = Invoke-WebRequest -Uri "$BaseUrl/health" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    } catch {
        # Health endpoint might not exist, try root
        try {
            $testResponse = Invoke-WebRequest -Uri "$BaseUrl/" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        } catch {
            # Stack not reachable
        }
    }
    
    if ($null -eq $testResponse) {
        Add-CheckResult -CheckName "Endpoint probe (stack reachable)" -Status "WARN" -Notes "Docker stack not reachable at $BaseUrl, skipping endpoint probe" -Blocking $false
    } else {
        # Stack is reachable, test endpoint
        try {
            $endpointResponse = Invoke-WebRequest -Uri "$BaseUrl/api/v1/commerce/listings" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            
            # Should not reach here (should be 401/403)
            Add-CheckResult -CheckName "Endpoint probe (unauthorized response)" -Status "WARN" -Notes "Unexpected response (expected 401/403, got $($endpointResponse.StatusCode))" -Blocking $false
        } catch {
            $webException = $_.Exception
            if ($webException.Response) {
                $statusCode = [int]$webException.Response.StatusCode.value__
                
                if ($statusCode -eq 401 -or $statusCode -eq 403) {
                    # Expected unauthorized response
                    try {
                        $stream = $webException.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $responseBody = $reader.ReadToEnd()
                        $reader.Close()
                        $stream.Close()
                        
                        # Check if response contains request_id
                        if ($responseBody -match "request_id" -or $responseBody -match "requestId") {
                            Add-CheckResult -CheckName "Endpoint probe (unauthorized response)" -Status "PASS" -Notes "Unauthorized endpoint returns 401/403 with request_id in body"
                        } else {
                            Add-CheckResult -CheckName "Endpoint probe (unauthorized response)" -Status "WARN" -Notes "Unauthorized endpoint returns $statusCode but missing request_id in body" -Blocking $false
                        }
                    } catch {
                        Add-CheckResult -CheckName "Endpoint probe (unauthorized response)" -Status "WARN" -Notes "Could not read response body: $($_.Exception.Message)" -Blocking $false
                    }
                } else {
                    Add-CheckResult -CheckName "Endpoint probe (unauthorized response)" -Status "WARN" -Notes "Unexpected status code: $statusCode (expected 401/403)" -Blocking $false
                }
            } else {
                Add-CheckResult -CheckName "Endpoint probe (unauthorized response)" -Status "WARN" -Notes "Request failed: $($_.Exception.Message)" -Blocking $false
            }
        }
    }
} catch {
    Add-CheckResult -CheckName "Endpoint probe (stack reachable)" -Status "WARN" -Notes "Could not probe endpoint: $($_.Exception.Message)" -Blocking $false
}

Write-Host ""

# Print results table
Write-Host "=== OPENAPI CONTRACT CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table -Property Check, Status, Notes -AutoSize
Write-Host ""

# Overall status
Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
Write-Host ""

# Exit
Invoke-OpsExit $overallExitCode





