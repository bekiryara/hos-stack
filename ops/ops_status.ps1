# ops_status.ps1 - Unified Ops Dashboard
# Aggregates all ops checks into a single status report

$ErrorActionPreference = "Continue"

Write-Host "=== UNIFIED OPS STATUS DASHBOARD ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Results table
$results = @()

# Helper: Run script and capture status
function Invoke-OpsCheck {
    param(
        [string]$CheckName,
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    
    Write-Host "Running $CheckName..." -ForegroundColor Yellow
    
    $output = @()
    $exitCode = 0
    $status = "PASS"
    $notes = ""
    
    try {
        # Capture output
        $scriptOutput = & $ScriptPath $Arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        
        # Determine status from exit code
        if ($exitCode -eq 0) {
            $status = "PASS"
        } elseif ($exitCode -eq 2) {
            $status = "WARN"
        } else {
            $status = "FAIL"
        }
        
        # Extract key notes from output (last few lines)
        $outputLines = $scriptOutput -split "`n" | Where-Object { $_.Trim() -ne "" }
        if ($outputLines.Count -gt 0) {
            $notes = ($outputLines[-3..-1] | Where-Object { $_ -ne $null }) -join "; "
            if ($notes.Length -gt 100) {
                $notes = $notes.Substring(0, 97) + "..."
            }
        }
        
    } catch {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Error: $($_.Exception.Message)"
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

# Helper: Check error contract (422 and 404 envelopes)
function Test-ErrorContract {
    Write-Host "Running Error Contract Check..." -ForegroundColor Yellow
    
    $status = "PASS"
    $exitCode = 0
    $notes = ""
    $failures = @()
    
    try {
        # Test 422 Validation Error
        $response422 = curl.exe -sS -i -X POST http://localhost:8080/auth/login `
            -H "Content-Type: application/json" `
            -H "Accept: application/json" `
            -d "{}" 2>&1
        
        $status422 = ($response422 | Select-String -Pattern "HTTP/\d\.\d\s+(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
        $body422 = ($response422 | Select-String -Pattern '\{.*\}' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1)
        
        if ($status422 -ne "422") {
            $failures += "422 status check failed (got $status422)"
        }
        
        if ($body422 -and $body422 -match '"ok"\s*:\s*false' -and 
            $body422 -match '"error_code"\s*:\s*"VALIDATION_ERROR"' -and
            $body422 -match '"request_id"' -and
            $body422 -match '"details"') {
            # PASS
        } else {
            $failures += "422 envelope missing required fields"
        }
        
        # Test 404 Not Found
        $response404 = curl.exe -sS -i -H "Accept: application/json" http://localhost:8080/api/non-existent-endpoint 2>&1
        
        $status404 = ($response404 | Select-String -Pattern "HTTP/\d\.\d\s+(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
        $body404 = ($response404 | Select-String -Pattern '\{.*\}' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1)
        
        if ($status404 -ne "404") {
            $failures += "404 status check failed (got $status404)"
        }
        
        if ($body404 -and $body404 -match '"ok"\s*:\s*false' -and 
            $body404 -match '"error_code"\s*:\s*"NOT_FOUND"' -and
            $body404 -match '"request_id"') {
            # PASS
        } else {
            $failures += "404 envelope missing required fields"
        }
        
        if ($failures.Count -gt 0) {
            $status = "FAIL"
            $exitCode = 1
            $notes = $failures -join "; "
        } else {
            $notes = "422 and 404 envelopes correct"
        }
        
    } catch {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Error: $($_.Exception.Message)"
    }
    
    $results += [PSCustomObject]@{
        Check = "Error Contract"
        Status = $status
        ExitCode = $exitCode
        Notes = $notes
    }
    
    return @{
        Status = $status
        ExitCode = $exitCode
    }
}

# Run all checks
Write-Host "=== Running Ops Checks ===" -ForegroundColor Cyan
Write-Host ""

# a) doctor.ps1
$doctorResult = Invoke-OpsCheck -CheckName "Repository Doctor" -ScriptPath ".\ops\doctor.ps1"

# b) verify.ps1
$verifyResult = Invoke-OpsCheck -CheckName "Stack Verification" -ScriptPath ".\ops\verify.ps1"

# c) triage.ps1
$triageResult = Invoke-OpsCheck -CheckName "Incident Triage" -ScriptPath ".\ops\triage.ps1"

# d) slo_check.ps1
$sloResult = Invoke-OpsCheck -CheckName "SLO Check" -ScriptPath ".\ops\slo_check.ps1" -Arguments @("-N", "10")

# e) security_audit.ps1
$securityResult = Invoke-OpsCheck -CheckName "Security Audit" -ScriptPath ".\ops\security_audit.ps1"

# f) conformance.ps1
$conformanceResult = Invoke-OpsCheck -CheckName "Conformance" -ScriptPath ".\ops\conformance.ps1"

# g) routes_snapshot.ps1
$routesResult = Invoke-OpsCheck -CheckName "Routes Snapshot" -ScriptPath ".\ops\routes_snapshot.ps1"

# h) schema_snapshot.ps1
$schemaResult = Invoke-OpsCheck -CheckName "Schema Snapshot" -ScriptPath ".\ops\schema_snapshot.ps1"

# i) error-contract check
$errorContractResult = Test-ErrorContract

# Print results table
Write-Host ""
Write-Host "=== OPS STATUS RESULTS ===" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property Check, Status, ExitCode, Notes -AutoSize

# Determine overall status
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "OVERALL STATUS: FAIL ($failCount failures, $warnCount warnings)" -ForegroundColor Red
    
    # Generate incident bundle
    Write-Host ""
    Write-Host "Generating incident bundle..." -ForegroundColor Yellow
    try {
        $bundleOutput = & .\ops\incident_bundle.ps1 2>&1 | Out-String
        # Extract bundle path from output (look for "incident_bundle_YYYYMMDD_HHMMSS" pattern)
        $bundlePath = ($bundleOutput | Select-String -Pattern "incident_bundle_\d{8}_\d{6}" | Select-Object -First 1)
        if ($bundlePath) {
            $bundlePath = $bundlePath.Matches.Value
            Write-Host "INCIDENT_BUNDLE_PATH=incident_bundles/$bundlePath" -ForegroundColor Yellow
        } else {
            # Fallback: try to find any path mentioned
            $bundlePath = ($bundleOutput | Select-String -Pattern "incident_bundles[\\/]incident_bundle_\d{8}_\d{6}" | Select-Object -First 1)
            if ($bundlePath) {
                Write-Host "INCIDENT_BUNDLE_PATH=$($bundlePath.Matches.Value)" -ForegroundColor Yellow
            } else {
                Write-Host "INCIDENT_BUNDLE_PATH=incident_bundles/ (check output above)" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "Warning: Failed to generate incident bundle: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Host "OVERALL STATUS: WARN ($warnCount warnings)" -ForegroundColor Yellow
    exit 2
} else {
    Write-Host "OVERALL STATUS: PASS (All checks passed)" -ForegroundColor Green
    exit 0
}

