# request_trace.ps1 - Request ID Log Correlation
# Traces request_id across Pazar and H-OS logs

param(
    [Parameter(Mandatory=$true)]
    [string]$RequestId,
    
    [int]$Tail = 2000,
    
    [int]$Context = 2,
    
    [int]$SinceMinutes = 0
)

$ErrorActionPreference = "Continue"

# Load shared helpers
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

Write-Host "=== REQUEST TRACE (Request ID: $RequestId) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Check if docker compose is available
try {
    $composeCheck = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose not available" -ForegroundColor Red
        Invoke-OpsExit 1
        return
    }
} catch {
    Write-Host "FAIL: docker compose not available: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-OpsExit 1
    return
}

# Check if services are running
try {
    $services = docker compose ps --format json 2>&1 | ConvertFrom-Json
    $runningServices = $services | Where-Object { $_.State -eq "running" -or $_.State -eq "Up" }
    if ($runningServices.Count -eq 0) {
        Write-Host "WARN: No docker compose services running" -ForegroundColor Yellow
        Write-Host "Attempting to start services..." -ForegroundColor Yellow
        docker compose up -d 2>&1 | Out-Null
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Host "WARN: Could not check docker compose services: $($_.Exception.Message)" -ForegroundColor Yellow
}

$foundMatches = $false
$serviceMatches = @{}

# Helper: Search logs for request_id
function Search-ServiceLogs {
    param(
        [string]$ServiceName,
        [string]$SearchPattern
    )
    
    Write-Host "=== Searching $ServiceName logs ===" -ForegroundColor Yellow
    
    $matches = @()
    
    try {
        # Build docker compose logs command
        $logArgs = @("compose", "logs", "--no-color")
        
        if ($SinceMinutes -gt 0) {
            $logArgs += "--since"
            $logArgs += "${SinceMinutes}m"
        } else {
            $logArgs += "--tail"
            $logArgs += "$Tail"
        }
        
        $logArgs += $ServiceName
        
        # Get logs
        $logOutput = docker $logArgs 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # Search for request_id matches with context
            $lines = $logOutput -split "`n"
            $matchIndices = @()
            
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match $SearchPattern) {
                    $matchIndices += $i
                }
            }
            
            if ($matchIndices.Count -gt 0) {
                $foundMatches = $true
                $serviceMatches[$ServiceName] = $matchIndices.Count
                
                Write-Host "Found $($matchIndices.Count) match(es) in $ServiceName" -ForegroundColor Green
                Write-Host ""
                
                # Show matches with context
                foreach ($idx in $matchIndices) {
                    $startIdx = [Math]::Max(0, $idx - $Context)
                    $endIdx = [Math]::Min($lines.Count - 1, $idx + $Context)
                    
                    Write-Host "--- Match at line $($idx + 1) ---" -ForegroundColor Cyan
                    for ($j = $startIdx; $j -le $endIdx; $j++) {
                        if ($j -eq $idx) {
                            Write-Host $lines[$j] -ForegroundColor Yellow
                        } else {
                            Write-Host $lines[$j] -ForegroundColor Gray
                        }
                    }
                    Write-Host ""
                }
            } else {
                Write-Host "No matches found in $ServiceName" -ForegroundColor Gray
            }
        } else {
            Write-Host "WARN: Could not retrieve logs from $ServiceName" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WARN: Error searching $ServiceName logs: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $matches
}

# Search pazar-app logs
$pazarPattern = [regex]::Escape($RequestId)
Search-ServiceLogs -ServiceName "pazar-app" -SearchPattern $pazarPattern

Write-Host ""

# Search hos-api logs
$hosPattern = [regex]::Escape($RequestId)
Search-ServiceLogs -ServiceName "hos-api" -SearchPattern $hosPattern

Write-Host ""

# Check pazar-app storage/logs/laravel.log if it exists
$laravelLogPath = "work/pazar/storage/logs/laravel.log"
if (Test-Path $laravelLogPath) {
    Write-Host "=== Searching pazar-app storage/logs/laravel.log ===" -ForegroundColor Yellow
    
    try {
        # Use Select-String with context
        $logMatches = Select-String -Path $laravelLogPath -Pattern $pazarPattern -Context $Context, $Context
        
        if ($logMatches) {
            $foundMatches = $true
            $matchCount = ($logMatches | Measure-Object).Count
            $serviceMatches["pazar-app-laravel.log"] = $matchCount
            
            Write-Host "Found $matchCount match(es) in laravel.log" -ForegroundColor Green
            Write-Host ""
            
            # Show last 50 matches (limit output)
            $limitedMatches = $logMatches | Select-Object -Last 50
            
            foreach ($match in $limitedMatches) {
                Write-Host "--- Match at line $($match.LineNumber) ---" -ForegroundColor Cyan
                if ($match.Context) {
                    foreach ($line in $match.Context.PreContext) {
                        Write-Host $line -ForegroundColor Gray
                    }
                }
                Write-Host $match.Line -ForegroundColor Yellow
                if ($match.Context) {
                    foreach ($line in $match.Context.PostContext) {
                        Write-Host $line -ForegroundColor Gray
                    }
                }
                Write-Host ""
            }
            
            if ($matchCount -gt 50) {
                Write-Host "... ($($matchCount - 50) more matches, showing last 50)" -ForegroundColor Gray
            }
        } else {
            Write-Host "No matches found in laravel.log" -ForegroundColor Gray
        }
    } catch {
        Write-Host "WARN: Error searching laravel.log: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== TRACE SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

if ($foundMatches) {
    Write-Host "Request ID found in:" -ForegroundColor Green
    foreach ($service in $serviceMatches.Keys) {
        Write-Host "  - $service : $($serviceMatches[$service]) match(es)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "OVERALL STATUS: PASS (Request ID found in logs)" -ForegroundColor Green
    Invoke-OpsExit 0
    return
} else {
    Write-Host "Request ID NOT found in any service logs" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  1. Request ID is incorrect or malformed" -ForegroundColor Gray
    Write-Host "  2. Logs have been rotated/cleared" -ForegroundColor Gray
    Write-Host "  3. Request was not processed by any service" -ForegroundColor Gray
    Write-Host "  4. Time window is too narrow (try -SinceMinutes with larger value)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Recommended commands:" -ForegroundColor Yellow
    Write-Host "  - Check all logs: docker compose logs --tail 5000 pazar-app hos-api" -ForegroundColor Gray
    Write-Host "  - Check recent logs: docker compose logs --since 1h pazar-app hos-api" -ForegroundColor Gray
    Write-Host "  - Verify request ID format: Should be UUID (e.g., 550e8400-e29b-41d4-a716-446655440000)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "OVERALL STATUS: WARN (No matches found)" -ForegroundColor Yellow
    Invoke-OpsExit 2
    return
}

