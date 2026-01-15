# smoke_surface.ps1 - Smoke Surface Gate
# Validates critical surfaces don't return 500/regression errors
# PowerShell 5.1 compatible, ASCII-only output, safe-exit behavior

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$PrometheusUrl = "http://localhost:9090"
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

Write-Host "=== SMOKE SURFACE GATE ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
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

# Helper: Check for UTF-8 BOM
function Test-Utf8Bom {
    param([byte[]]$Bytes)
    
    if ($Bytes.Length -lt 3) {
        return $false
    }
    
    # UTF-8 BOM: EF BB BF
    return ($Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF)
}

# Check 1: Pazar /up → 200
Write-Host "Check 1: Pazar /up endpoint" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/up" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        Add-CheckResult -CheckName "Pazar /up" -Status "PASS" -Notes "HTTP 200 OK"
    } else {
        Add-CheckResult -CheckName "Pazar /up" -Status "FAIL" -Notes "Expected HTTP 200, got $($response.StatusCode)"
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        Add-CheckResult -CheckName "Pazar /up" -Status "FAIL" -Notes "HTTP $statusCode - $($_.Exception.Message)"
    } else {
        Add-CheckResult -CheckName "Pazar /up" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)"
    }
}

Write-Host ""

# Check 2: Pazar /metrics → 200 AND Content-Type starts with "text/plain" AND body contains "pazar_build_info" AND no BOM artifact
Write-Host "Check 2: Pazar /metrics endpoint" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/metrics" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    $statusOk = $false
    $contentTypeOk = $false
    $bodyContainsMetric = $false
    $noBom = $false
    $notes = @()
    
    # Status code check
    if ($response.StatusCode -eq 200) {
        $statusOk = $true
    } else {
        $notes += "Expected HTTP 200, got $($response.StatusCode)"
    }
    
    # Content-Type check
    $contentType = $response.Headers["Content-Type"]
    if ($null -eq $contentType) {
        $contentType = $response.Content.Headers.ContentType.ToString()
    }
    if ($contentType -and $contentType.StartsWith("text/plain")) {
        $contentTypeOk = $true
    } else {
        $notes += "Expected Content-Type starting with 'text/plain', got '$contentType'"
    }
    
    # Body content check (check for any pazar_ metric - pazar_product_create_total, pazar_product_disable_total, pazar_products_total, or pazar_build_info)
    $body = $response.Content
    if ($body -match "pazar_\w+") {
        $bodyContainsMetric = $true
    } else {
        $notes += "Body does not contain pazar_ metric (expected pazar_product_create_total, pazar_product_disable_total, pazar_products_total, or pazar_build_info)"
    }
    
    # BOM check (check raw bytes)
    try {
        $rawBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        if (-not (Test-Utf8Bom -Bytes $rawBytes)) {
            $noBom = $true
        } else {
            $notes += "Response contains UTF-8 BOM artifact"
        }
    } catch {
        # If we can't check BOM, assume it's OK (non-blocking)
        $noBom = $true
    }
    
    if ($statusOk -and $contentTypeOk -and $bodyContainsMetric -and $noBom) {
        Add-CheckResult -CheckName "Pazar /metrics" -Status "PASS" -Notes "HTTP 200, Content-Type text/plain, body contains pazar_ metric, no BOM"
    } else {
        $failNotes = if ($notes.Count -gt 0) { $notes -join "; " } else { "One or more checks failed" }
        Add-CheckResult -CheckName "Pazar /metrics" -Status "FAIL" -Notes $failNotes
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        Add-CheckResult -CheckName "Pazar /metrics" -Status "FAIL" -Notes "HTTP $statusCode - $($_.Exception.Message)"
    } else {
        Add-CheckResult -CheckName "Pazar /metrics" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)"
    }
}

Write-Host ""

# Check 3: API error contract smoke - GET /api/non-existent-endpoint → 404 JSON envelope includes request_id
Write-Host "Check 3: API error contract smoke" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/non-existent-endpoint-$(Get-Random)" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    # Should not reach here (should be 404)
    Add-CheckResult -CheckName "API error contract" -Status "FAIL" -Notes "Expected HTTP 404, got $($response.StatusCode)"
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        
        if ($statusCode -eq 404) {
            # Read response body
            try {
                $stream = $webException.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
                
                # Parse JSON
                try {
                    $json = $responseBody | ConvertFrom-Json
                    
                    # Check for error envelope structure
                    $hasOk = $json.PSObject.Properties.Name -contains "ok"
                    $hasErrorCode = $json.PSObject.Properties.Name -contains "error_code"
                    $hasMessage = $json.PSObject.Properties.Name -contains "message"
                    $hasRequestId = $json.PSObject.Properties.Name -contains "request_id"
                    $requestIdNotNull = $null -ne $json.request_id -and $json.request_id -ne ""
                    
                    if ($hasOk -and $hasErrorCode -and $hasMessage -and $hasRequestId -and $requestIdNotNull) {
                        Add-CheckResult -CheckName "API error contract" -Status "PASS" -Notes "HTTP 404 with JSON envelope (ok, error_code, message, request_id non-null)"
                    } else {
                        $missing = @()
                        if (-not $hasOk) { $missing += "ok" }
                        if (-not $hasErrorCode) { $missing += "error_code" }
                        if (-not $hasMessage) { $missing += "message" }
                        if (-not $hasRequestId) { $missing += "request_id" }
                        if (-not $requestIdNotNull) { $missing += "request_id (null/empty)" }
                        Add-CheckResult -CheckName "API error contract" -Status "FAIL" -Notes "HTTP 404 but missing fields: $($missing -join ', ')"
                    }
                } catch {
                    Add-CheckResult -CheckName "API error contract" -Status "FAIL" -Notes "HTTP 404 but response is not valid JSON: $($_.Exception.Message)"
                }
            } catch {
                Add-CheckResult -CheckName "API error contract" -Status "FAIL" -Notes "HTTP 404 but could not read response body: $($_.Exception.Message)"
            }
        } else {
            Add-CheckResult -CheckName "API error contract" -Status "FAIL" -Notes "Expected HTTP 404, got $statusCode"
        }
    } else {
        Add-CheckResult -CheckName "API error contract" -Status "FAIL" -Notes "Connection error: $($_.Exception.Message)"
    }
}

Write-Host ""

# Check 4: Admin UI surface must not 500 - GET /ui/admin/control-center (no auth) should be either 200 or 302/401/403, BUT MUST NOT be 500
Write-Host "Check 4: Admin UI surface (no 500)" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/ui/admin/control-center" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop -MaximumRedirection 0
    
    $statusCode = $response.StatusCode
    
    if ($statusCode -eq 200) {
        Add-CheckResult -CheckName "Admin UI surface" -Status "PASS" -Notes "HTTP 200 OK"
    } elseif ($statusCode -eq 302 -or $statusCode -eq 401 -or $statusCode -eq 403) {
        Add-CheckResult -CheckName "Admin UI surface" -Status "PASS" -Notes "HTTP $statusCode (redirect/unauthorized, acceptable)"
    } else {
        Add-CheckResult -CheckName "Admin UI surface" -Status "FAIL" -Notes "Unexpected status code: $statusCode (expected 200/302/401/403)"
    }
} catch {
    $webException = $_.Exception
    if ($webException.Response) {
        $statusCode = [int]$webException.Response.StatusCode.value__
        
        if ($statusCode -eq 500) {
            # Read response body to check for Monolog permission errors
            $body = ""
            try {
                $stream = $webException.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
            } catch {
                # Could not read body
            }
            
            $hasMonologError = $body -match "Permission denied" -or $body -match "Monolog" -or $body -match "storage/logs"
            
            $remediationHints = @()
            $remediationHints += "storage/logs and bootstrap/cache writable by php-fpm user (www-data)"
            $remediationHints += "ensure runtime permission fix executes on every container start (not only one-time init)"
            $remediationHints += "confirm storage volume is named volume not bind mount (avoid Windows perms)"
            
            $notes = "HTTP 500 Internal Server Error"
            if ($hasMonologError) {
                $notes += " (Monolog permission error detected)"
            }
            $notes += ". Remediation: $($remediationHints -join '; ')"
            
            Add-CheckResult -CheckName "Admin UI surface" -Status "FAIL" -Notes $notes
        } elseif ($statusCode -eq 302 -or $statusCode -eq 401 -or $statusCode -eq 403) {
            Add-CheckResult -CheckName "Admin UI surface" -Status "PASS" -Notes "HTTP $statusCode (redirect/unauthorized, acceptable)"
        } else {
            Add-CheckResult -CheckName "Admin UI surface" -Status "FAIL" -Notes "HTTP $statusCode (expected 200/302/401/403, NOT 500)"
        }
    } else {
        # Check if it's a redirect exception (302)
        if ($_.Exception.Message -match "302" -or $_.Exception.Message -match "redirect") {
            Add-CheckResult -CheckName "Admin UI surface" -Status "PASS" -Notes "Redirect (302, acceptable)"
        } else {
            Add-CheckResult -CheckName "Admin UI surface" -Status "WARN" -Notes "Connection error (may be acceptable if stack not running): $($_.Exception.Message)" -Blocking $false
        }
    }
}

Write-Host ""

# Check 5: Optional (WARN-only) - If Prometheus reachable (9090), verify /api/v1/targets has pazar job up; else WARN
Write-Host "Check 5: Prometheus targets (optional)" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "$PrometheusUrl/api/v1/targets" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        try {
            $json = $response.Content | ConvertFrom-Json
            
            # Check if pazar job is in targets
            $pazarJobFound = $false
            $pazarJobUp = $false
            
            if ($json.data -and $json.data.activeTargets) {
                foreach ($target in $json.data.activeTargets) {
                    if ($target.labels -and $target.labels.job -and $target.labels.job -match "pazar") {
                        $pazarJobFound = $true
                        if ($target.health -eq "up") {
                            $pazarJobUp = $true
                            break
                        }
                    }
                }
            }
            
            if ($pazarJobUp) {
                Add-CheckResult -CheckName "Prometheus targets" -Status "PASS" -Notes "Pazar job found and UP" -Blocking $false
            } elseif ($pazarJobFound) {
                Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Pazar job found but not UP" -Blocking $false
            } else {
                Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Pazar job not found in targets" -Blocking $false
            }
        } catch {
            Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus reachable but response is not valid JSON: $($_.Exception.Message)" -Blocking $false
        }
    } else {
        Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus returned HTTP $($response.StatusCode)" -Blocking $false
    }
} catch {
    Add-CheckResult -CheckName "Prometheus targets" -Status "WARN" -Notes "Prometheus not reachable at $PrometheusUrl (optional check)" -Blocking $false
}

Write-Host ""

# Print results table
Write-Host "=== SMOKE SURFACE GATE RESULTS ===" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table -Property Check, Status, Notes -AutoSize
Write-Host ""

# Overall status
Write-Host "OVERALL STATUS: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "PASS") { "Green" } elseif ($overallStatus -eq "WARN") { "Yellow" } else { "Red" })
Write-Host ""

# Exit
Invoke-OpsExit $overallExitCode

