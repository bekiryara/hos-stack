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

# Results table
$results = @()

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

# Auto-select routes
$adminRoute = $routes | Where-Object { 
    $_.uri -like "/admin/*" -and 
    $_.method -eq "GET" -and 
    ($_.middleware -contains "auth.any" -or $_.middleware -contains "super.admin")
} | Select-Object -First 1

$panelRoute = $routes | Where-Object { 
    $_.uri -like "/panel/{tenant_slug}/*" -and 
    $_.method -eq "GET" -and 
    ($_.middleware -contains "tenant.user" -or $_.middleware -contains "auth.any")
} | Select-Object -First 1

if (-not $adminRoute) {
    Write-Host "WARN: No admin route found in snapshot" -ForegroundColor Yellow
    $adminRoute = @{ uri = "/admin/tenants"; method = "GET" }
}

if (-not $panelRoute) {
    Write-Host "WARN: No panel route found in snapshot" -ForegroundColor Yellow
    $panelRoute = @{ uri = "/panel/{tenant_slug}/ping"; method = "GET" }
}

Write-Host "Selected admin route: $($adminRoute.method) $($adminRoute.uri)" -ForegroundColor Gray
Write-Host "Selected panel route: $($panelRoute.method) $($panelRoute.uri)" -ForegroundColor Gray
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
            if ($ExpectJsonEnvelope) {
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
                if ($ExpectJsonEnvelope) {
                    try {
                        $stream = $errorResponse.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $body = $reader.ReadToEnd()
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
    
    $results += [PSCustomObject]@{
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

# Check A: Admin unauthorized access
$adminUrl = "http://localhost:8080$($adminRoute.uri)"
Test-AuthResponse -CheckName "Admin Unauthorized Access" `
    -Method "GET" `
    -Url $adminUrl `
    -ExpectedStatusCodes @(401, 403) `
    -ExpectJsonEnvelope $true

# Check B: Panel unauthorized access
$panelUrlTemplate = $panelRoute.uri -replace '\{tenant_slug\}', 'test-tenant'
$panelUrl = "http://localhost:8080$panelUrlTemplate"
Test-AuthResponse -CheckName "Panel Unauthorized Access" `
    -Method "GET" `
    -Url $panelUrl `
    -ExpectedStatusCodes @(401, 403) `
    -ExpectJsonEnvelope $true

# Check C: Tenant boundary isolation
Write-Host "Testing tenant boundary isolation..." -ForegroundColor Yellow

$tenantBoundaryStatus = "PASS"
$tenantBoundaryNotes = ""
$tenantBoundaryExitCode = 0

# Get test credentials from environment
$testEmail = $env:TENANT_TEST_EMAIL
$testPassword = $env:TENANT_TEST_PASSWORD
$tenantA = if ($null -ne $env:TENANT_A_SLUG) { $env:TENANT_A_SLUG } else { "tenant-a" }
$tenantB = if ($null -ne $env:TENANT_B_SLUG) { $env:TENANT_B_SLUG } else { "tenant-b" }

if (-not $testEmail -or -not $testPassword) {
    $tenantBoundaryStatus = "WARN"
    $tenantBoundaryNotes = "Test credentials not set (TENANT_TEST_EMAIL, TENANT_TEST_PASSWORD). Tenant boundary check skipped."
    $tenantBoundaryExitCode = 2
    Write-Host "WARN: Test credentials not set. Skipping tenant boundary check." -ForegroundColor Yellow
    Write-Host "Set TENANT_TEST_EMAIL, TENANT_TEST_PASSWORD, TENANT_A_SLUG, TENANT_B_SLUG environment variables to enable." -ForegroundColor Gray
} else {
    try {
        # Login as test user
        Write-Host "  Logging in as test user..." -ForegroundColor DarkGray
        $loginBody = @{
            email = $testEmail
            password = $testPassword
        } | ConvertTo-Json
        
        $loginResponse = Invoke-WebRequest -Uri "http://localhost:8080/auth/login" `
            -Method "POST" `
            -Headers @{
                "Content-Type" = "application/json"
                "Accept" = "application/json"
            } `
            -Body $loginBody `
            -UseBasicParsing `
            -TimeoutSec 5 `
            -ErrorAction Stop
        
        $loginJson = $loginResponse.Content | ConvertFrom-Json
        $token = $loginJson.token
        
        if (-not $token) {
            $tenantBoundaryStatus = "FAIL"
            $tenantBoundaryNotes = "Login failed: No token in response"
            $tenantBoundaryExitCode = 1
        } else {
            # Access tenant A (should PASS)
            Write-Host "  Accessing tenant A ($tenantA)..." -ForegroundColor DarkGray
            $tenantAUrl = $panelUrlTemplate -replace 'test-tenant', $tenantA
            $tenantAUrl = "http://localhost:8080$tenantAUrl"
            
            try {
                $tenantAResponse = Invoke-WebRequest -Uri $tenantAUrl `
                    -Method "GET" `
                    -Headers @{
                        "Authorization" = "Bearer $token"
                        "Accept" = "application/json"
                    } `
                    -UseBasicParsing `
                    -TimeoutSec 5 `
                    -ErrorAction Stop
                
                if ($tenantAResponse.StatusCode -eq 200) {
                    # Access tenant B (should be 403)
                    Write-Host "  Accessing tenant B ($tenantB)..." -ForegroundColor DarkGray
                    $tenantBUrl = $panelUrlTemplate -replace 'test-tenant', $tenantB
                    $tenantBUrl = "http://localhost:8080$tenantBUrl"
                    
                    try {
                        $tenantBResponse = Invoke-WebRequest -Uri $tenantBUrl `
                            -Method "GET" `
                            -Headers @{
                                "Authorization" = "Bearer $token"
                                "Accept" = "application/json"
                            } `
                            -UseBasicParsing `
                            -TimeoutSec 5 `
                            -ErrorAction Stop
                        
                        # Should not reach here - should be 403
                        $tenantBoundaryStatus = "FAIL"
                        $tenantBoundaryNotes = "Tenant B access allowed (expected 403 FORBIDDEN)"
                        $tenantBoundaryExitCode = 1
                    } catch {
                        $errorResponse = $_.Exception.Response
                        if ($errorResponse) {
                            $statusCode = [int]$errorResponse.StatusCode.value__
                            if ($statusCode -eq 403) {
                                # Check JSON envelope
                                try {
                                    $stream = $errorResponse.GetResponseStream()
                                    $reader = New-Object System.IO.StreamReader($stream)
                                    $body = $reader.ReadToEnd()
                                    $json = $body | ConvertFrom-Json
                                    if ($json.ok -eq $false -and ($json.error_code -eq "FORBIDDEN" -or $json.error_code -eq "UNAUTHORIZED")) {
                                        $tenantBoundaryNotes = "Tenant boundary enforced: Tenant A access OK, Tenant B blocked (403 FORBIDDEN)"
                                    } else {
                                        $tenantBoundaryStatus = "WARN"
                                        $tenantBoundaryNotes = "Tenant B blocked (403), but envelope incomplete"
                                        $tenantBoundaryExitCode = 2
                                    }
                                } catch {
                                    $tenantBoundaryStatus = "WARN"
                                    $tenantBoundaryNotes = "Tenant B blocked (403), but not valid JSON"
                                    $tenantBoundaryExitCode = 2
                                }
                            } else {
                                $tenantBoundaryStatus = "FAIL"
                                $tenantBoundaryNotes = "Tenant B access returned $statusCode (expected 403 FORBIDDEN)"
                                $tenantBoundaryExitCode = 1
                            }
                        } else {
                            $tenantBoundaryStatus = "FAIL"
                            $tenantBoundaryNotes = "Tenant B access failed: $($_.Exception.Message)"
                            $tenantBoundaryExitCode = 1
                        }
                    }
                } else {
                    $tenantBoundaryStatus = "FAIL"
                    $tenantBoundaryNotes = "Tenant A access returned $($tenantAResponse.StatusCode) (expected 200)"
                    $tenantBoundaryExitCode = 1
                }
            } catch {
                $errorResponse = $_.Exception.Response
                if ($errorResponse) {
                    $statusCode = [int]$errorResponse.StatusCode.value__
                    $tenantBoundaryStatus = "FAIL"
                    $tenantBoundaryNotes = "Tenant A access failed: Status $statusCode"
                    $tenantBoundaryExitCode = 1
                } else {
                    $tenantBoundaryStatus = "FAIL"
                    $tenantBoundaryNotes = "Tenant A access failed: $($_.Exception.Message)"
                    $tenantBoundaryExitCode = 1
                }
            }
        }
    } catch {
        $tenantBoundaryStatus = "FAIL"
        $tenantBoundaryNotes = "Login failed: $($_.Exception.Message)"
        $tenantBoundaryExitCode = 1
    }
}

$results += [PSCustomObject]@{
    Check = "Tenant Boundary Isolation"
    Status = $tenantBoundaryStatus
    ExitCode = $tenantBoundaryExitCode
    Notes = $tenantBoundaryNotes
}

# Print results table
Write-Host ""
Write-Host "=== TENANT BOUNDARY CHECK RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

# Determine overall status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    Invoke-OpsExit 2
    return
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
}

