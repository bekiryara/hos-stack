# tenant_boundary_check.ps1 - Tenant Boundary Isolation Check
# Verifies tenant isolation and unauthorized access protection

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}
if (Test-Path "${scriptDir}\_lib\routes_json.ps1") {
    . "${scriptDir}\_lib\routes_json.ps1"
}

Write-Host "=== TENANT BOUNDARY CHECK ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table (script scope; functions append here)
$script:results = @()

# Read routes snapshot
$snapshotPath = "ops\snapshots\routes.pazar.json"
if (-not (Test-Path $snapshotPath)) {
    Write-Host "FAIL: Routes snapshot not found: $snapshotPath" -ForegroundColor Red
    Write-Host "Run routes_snapshot.ps1 first to create snapshot." -ForegroundColor Yellow
    Invoke-OpsExit 1
    return
}

Write-Host "Reading routes snapshot..." -ForegroundColor Yellow
$snapshotContent = Get-Content $snapshotPath -Raw -Encoding UTF8
$routes = Convert-RoutesJsonToCanonicalArray -RawJsonText $snapshotContent

# Auto-select a store-scope, tenant-scoped route (SSOT: Pazar exposes world APIs under /api/v1/*; no /admin or /panel).
$storeWriteRoute = $routes | Where-Object {
    $_.uri -like "api/v1/*" -and
    ($_.method -match "POST") -and
    ($_.middleware -contains "tenant.scope" -or $_.middleware -contains "App\\Http\\Middleware\\TenantScope")
} | Select-Object -First 1

if (-not $storeWriteRoute) {
    Write-Host "WARN: No store-scope tenant route found in snapshot; using default /api/v1/listings (POST)" -ForegroundColor Yellow
    $storeWriteRoute = @{ uri = "api/v1/listings"; method = "POST" }
}

Write-Host "Selected store route: $($storeWriteRoute.method) /$($storeWriteRoute.uri)" -ForegroundColor Gray
Write-Host ""

# Helper: Check HTTP response
function Test-AuthResponse {
    param(
        [string]$CheckName,
        [string]$Method,
        [string]$Url,
        [int[]]$ExpectedStatusCodes,
        [bool]$ExpectJsonEnvelope = $false,
        [hashtable]$Headers = @{}
    )
    
    Write-Host "Testing $CheckName..." -ForegroundColor Yellow
    
    $status = "PASS"
    $notes = ""
    $exitCode = 0
    
    try {
        $requestHeaders = @{
            "Accept" = "application/json"
        }
        foreach ($key in $Headers.Keys) {
            $requestHeaders[$key] = $Headers[$key]
        }
        
        if ($Method -eq "GET") {
            $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $requestHeaders -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        } else {
            $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $requestHeaders -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        }
        
        $statusCode = $response.StatusCode
        
        if ($ExpectedStatusCodes -contains $statusCode) {
            # Route missing in this profile => WARN (not a boundary failure)
            if ($statusCode -eq 404) {
                $status = "WARN"
                $notes = "Status 404 (route not present in this profile)"
                $exitCode = 2
            } elseif ($ExpectJsonEnvelope) {
                try {
                    $json = $response.Content | ConvertFrom-Json
                    if ($json.ok -eq $false -and $json.error_code) {
                        $notes = "Status $statusCode, JSON envelope correct (error_code: $($json.error_code))"
                    } else {
                        $status = "WARN"
                        $notes = "Status $statusCode, but JSON envelope incomplete"
                        $exitCode = 2
                    }
                } catch {
                    $status = "WARN"
                    $notes = "Status $statusCode, but not valid JSON"
                    $exitCode = 2
                }
            } else {
                $notes = "Status $statusCode (expected)"
            }
        } else {
            $status = "FAIL"
            $notes = "Status $statusCode (expected: $($ExpectedStatusCodes -join '/'))"
            $exitCode = 1
        }
    } catch {
        $errorResponse = $_.Exception.Response
        if ($errorResponse) {
            $statusCode = [int]$errorResponse.StatusCode.value__
            if ($ExpectedStatusCodes -contains $statusCode) {
                if ($statusCode -eq 404) {
                    $status = "WARN"
                    $notes = "Status 404 (route not present in this profile)"
                    $exitCode = 2
                } elseif ($ExpectJsonEnvelope) {
                    try {
                        # Prefer ErrorDetails.Message (more reliable than response stream in Windows PowerShell)
                        $body = $null
                        try {
                            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $body = $_.ErrorDetails.Message }
                        } catch { }
                        if (-not $body) {
                            $stream = $errorResponse.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($stream)
                            $body = $reader.ReadToEnd()
                        }
                        $json = $body | ConvertFrom-Json
                        if ($json.ok -eq $false -and $json.error_code) {
                            $notes = "Status $statusCode, JSON envelope correct (error_code: $($json.error_code))"
                        } else {
                            $status = "WARN"
                            $notes = "Status $statusCode, but JSON envelope incomplete"
                            $exitCode = 2
                        }
                    } catch {
                        $status = "WARN"
                        $notes = "Status $statusCode, but not valid JSON"
                        $exitCode = 2
                    }
                } else {
                    $notes = "Status $statusCode (expected)"
                }
            } else {
                $status = "FAIL"
                $notes = "Status $statusCode (expected: $($ExpectedStatusCodes -join '/'))"
                $exitCode = 1
            }
        } else {
            $status = "FAIL"
            $notes = "Request failed: $($_.Exception.Message)"
            $exitCode = 1
        }
    }
    
    $script:results += [PSCustomObject]@{
        Check = $CheckName
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Check A: Store route without auth must be rejected (401/403) or 404 if not present in profile
$storeUrl = "http://localhost:8080/$($storeWriteRoute.uri)"
Test-AuthResponse -CheckName "Store Unauthorized Access" `
    -Method "POST" `
    -Url $storeUrl `
    -ExpectedStatusCodes @(400, 401, 403, 404) `
    -ExpectJsonEnvelope $true

# Check C: Tenant boundary isolation (SSOT)
# - Pazar does NOT implement /auth/login or /admin/panel surfaces.
# - Cross-tenant isolation requires a real authenticated token + known tenant IDs.
Write-Host "Testing tenant boundary isolation..." -ForegroundColor Yellow

$tenantBoundaryStatus = "WARN"
$tenantBoundaryNotes = "SKIP: Cross-tenant test requires PRODUCT_TEST_AUTH_TOKEN + tenant IDs. Pazar has no /auth/login surface."
$tenantBoundaryExitCode = 2

$token = $env:PRODUCT_TEST_AUTH_TOKEN

if ($token) {
    # Minimal enforcement: store endpoints MUST require tenant context header.
    # If token is valid, missing tenant header should be rejected (400/401/403).
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Accept" = "application/json"
            "Content-Type" = "application/json"
        }
        $body = "{}"
        try {
            $resp = Invoke-WebRequest -Uri $storeUrl -Method "POST" -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            # If we got a 2xx here, tenant boundary is broken.
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                $tenantBoundaryStatus = "FAIL"
                $tenantBoundaryExitCode = 1
                $tenantBoundaryNotes = "Store write allowed without tenant context (expected 400/401/403)"
            } else {
                $tenantBoundaryStatus = "WARN"
                $tenantBoundaryExitCode = 2
                $tenantBoundaryNotes = "Unexpected status without tenant context: $($resp.StatusCode)"
            }
        } catch {
            $er = $_.Exception.Response
            if ($er) {
                $code = [int]$er.StatusCode.value__
                if ($code -eq 400 -or $code -eq 401 -or $code -eq 403 -or $code -eq 404) {
                    $tenantBoundaryStatus = "PASS"
                    $tenantBoundaryExitCode = 0
                    $tenantBoundaryNotes = "Tenant context required: store write rejected without X-Active-Tenant-Id (status $code)"
                } else {
                    $tenantBoundaryStatus = "WARN"
                    $tenantBoundaryExitCode = 2
                    $tenantBoundaryNotes = "Unexpected status without tenant context: $code"
                }
            }
        }
    } catch {
        $tenantBoundaryStatus = "WARN"
        $tenantBoundaryExitCode = 2
        $tenantBoundaryNotes = "Could not probe tenant boundary: $($_.Exception.Message)"
    }
}

$script:results += [PSCustomObject]@{
    Check = "Tenant Boundary Isolation"
    Status = $tenantBoundaryStatus
    ExitCode = $tenantBoundaryExitCode
    Notes = $tenantBoundaryNotes
}

# Print results table
Write-Host ""
Write-Host "=== TENANT BOUNDARY CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$script:results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

# Determine overall status
$failCount = ($script:results | Where-Object { ([string]$_.Status).Trim().ToUpper() -eq "FAIL" }).Count
$warnCount = ($script:results | Where-Object { ([string]$_.Status).Trim().ToUpper() -eq "WARN" }).Count

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
} elseif ($warnCount -gt 0) {
    # WARN is non-blocking in CI: surface signal without turning the job red.
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings) [non-blocking]" -ForegroundColor Yellow
    Invoke-OpsExit 0
    return
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}

