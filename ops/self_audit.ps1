# self_audit.ps1 - Self-Audit Orchestrator
# Runs canonical checks and produces audit record with evidence
# PowerShell 5.1 compatible

param(
    [switch]$Ci
)

$ErrorActionPreference = "Continue"

# Load shared helpers if available
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    . "${scriptDir}\_lib\ops_output.ps1"
    Initialize-OpsOutput
}
if (Test-Path "${scriptDir}\_lib\ops_exit.ps1") {
    . "${scriptDir}\_lib\ops_exit.ps1"
    Initialize-OpsExit
}

# Ensure we're in repo root
$repoRoot = Split-Path -Parent $scriptDir
Push-Location $repoRoot

if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== SELF-AUDIT ORCHESTRATOR ==="
} else {
    Write-Host "=== SELF-AUDIT ORCHESTRATOR ===" -ForegroundColor Cyan
}
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Create audit folder
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$auditFolder = "_archive\audits\audit-$timestamp"

if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "Creating audit folder: $auditFolder"
} else {
    Write-Host "Creating audit folder: $auditFolder" -ForegroundColor Yellow
}

try {
    if (-not (Test-Path "_archive\audits")) {
        New-Item -ItemType Directory -Path "_archive\audits" -Force | Out-Null
    }
    if (Test-Path $auditFolder) {
        Remove-Item -Path $auditFolder -Recurse -Force
    }
    New-Item -ItemType Directory -Path $auditFolder -Force | Out-Null
    
    if (-not (Test-Path $auditFolder)) {
        if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
            Write-Fail "Failed to create audit folder: $auditFolder"
        } else {
            Write-Host "[FAIL] Failed to create audit folder: $auditFolder" -ForegroundColor Red
        }
        Pop-Location
        Invoke-OpsExit 1
        return 1
    }
} catch {
    if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
        Write-Fail "Error creating audit folder: $($_.Exception.Message)"
    } else {
        Write-Host "[FAIL] Error creating audit folder: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pop-Location
    Invoke-OpsExit 1
    return 1
}

# Track checks
$checks = @()
$hasFail = $false
$hasWarn = $false

# Helper: Run script and capture output
function Invoke-AuditCheck {
    param(
        [string]$CheckName,
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$OutputFile,
        [bool]$Required = $false
    )
    
    Write-Host "Running $CheckName..." -ForegroundColor Yellow
    
    $status = "SKIP"
    $exitCode = 0
    $notes = ""
    
    try {
        if (-not (Test-Path $ScriptPath)) {
            if ($Required) {
                $status = "FAIL"
                $exitCode = 1
                $notes = "Script not found: $ScriptPath"
                "[FAIL] $notes" | Out-File -FilePath $OutputFile -Encoding UTF8
                Write-Host "  [FAIL] Script not found: $ScriptPath" -ForegroundColor Red
                $script:hasFail = $true
            } else {
                $status = "SKIP"
                $exitCode = 0
                $notes = "Script not found: $ScriptPath"
                "[SKIP] $notes" | Out-File -FilePath $OutputFile -Encoding UTF8
                Write-Host "  [SKIP] Script not found: $ScriptPath" -ForegroundColor Gray
            }
        } else {
            if ($null -eq $Arguments) {
                $Arguments = @()
            }
            $output = & $ScriptPath @Arguments 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            
            $output | Out-File -FilePath $OutputFile -Encoding UTF8 -NoNewline
            
            if ($exitCode -eq 0) {
                $status = "PASS"
                Write-Host "  [PASS] $CheckName" -ForegroundColor Green
            } elseif ($exitCode -eq 2) {
                $status = "WARN"
                $notes = "Exit code: 2 (WARN)"
                Write-Host "  [WARN] $CheckName" -ForegroundColor Yellow
                $script:hasWarn = $true
            } else {
                $status = "FAIL"
                $notes = "Exit code: $exitCode (FAIL)"
                Write-Host "  [FAIL] $CheckName" -ForegroundColor Red
                $script:hasFail = $true
            }
        }
    } catch {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Error: $($_.Exception.Message)"
        $notes | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "  [FAIL] ${CheckName}: $($_.Exception.Message)" -ForegroundColor Red
        $script:hasFail = $true
    }
    
    $script:checks += [PSCustomObject]@{
        name = $CheckName
        status = $status
        exit_code = $exitCode
        notes = $notes
    }
}

# Collect metadata
Write-Host "=== Collecting Metadata ===" -ForegroundColor Cyan
try {
    $timestampISO = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $branch = & git rev-parse --abbrev-ref HEAD 2>&1
    $commit = & git rev-parse HEAD 2>&1
    $gitStatus = & git status --porcelain 2>&1 | Out-String
    $gitStatusCount = ($gitStatus -split "`n" | Where-Object { $_.Trim() -ne "" }).Count
    
    $hostname = $env:COMPUTERNAME
    if ($null -eq $hostname) {
        $hostname = $env:HOSTNAME
    }
    if ($null -eq $hostname) {
        $hostname = "unknown"
    }
    
    $pwshVersion = $PSVersionTable.PSVersion.ToString()
    
    $dockerVersion = "not available"
    try {
        $dockerVersionOutput = & docker --version 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $dockerVersionOutput -match 'Docker version\s+([^\s,]+)') {
            $dockerVersion = $matches[1]
        }
    } catch {
        # Ignore
    }
    
    $composeVersion = "not available"
    try {
        $composeVersionOutput = & docker compose version 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $composeVersionOutput -match 'Docker Compose version\s+v?([^\s,]+)') {
            $composeVersion = $matches[1]
        }
    } catch {
        # Ignore
    }
    
    $meta = @{
        timestamp = $timestampISO
        branch = $branch
        commit = $commit
        git_status_count = $gitStatusCount
        hostname = $hostname
        pwsh_version = $pwshVersion
        docker_version = $dockerVersion
        compose_version = $composeVersion
    }
    
    $metaJson = $meta | ConvertTo-Json -Depth 10
    $metaJson | Out-File -FilePath "${auditFolder}\meta.json" -Encoding UTF8
    Write-Host "  [OK] meta.json" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to collect metadata: $($_.Exception.Message)" -ForegroundColor Yellow
    $hasWarn = $true
    @{ error = $_.Exception.Message } | ConvertTo-Json | Out-File -FilePath "${auditFolder}\meta.json" -Encoding UTF8
}

# Run canonical checks
Write-Host ""
Write-Host "=== Running Canonical Checks ===" -ForegroundColor Cyan

# 1) doctor.ps1
Invoke-AuditCheck -CheckName "Repository Doctor" -ScriptPath "${scriptDir}\doctor.ps1" -OutputFile "${auditFolder}\doctor.txt" -Required $true

# 2) run_ops_status.ps1 (preferred, safe runner)
$opsStatusScript = "${scriptDir}\run_ops_status.ps1"
if (-not (Test-Path $opsStatusScript)) {
    $opsStatusScript = "${scriptDir}\ops_status.ps1"
}
Invoke-AuditCheck -CheckName "Ops Status" -ScriptPath $opsStatusScript -Arguments @("-Ci") -OutputFile "${auditFolder}\ops_status.txt" -Required $true

# 3) conformance.ps1
Invoke-AuditCheck -CheckName "Conformance" -ScriptPath "${scriptDir}\conformance.ps1" -OutputFile "${auditFolder}\conformance.txt" -Required $true

# 4) env_contract.ps1
Invoke-AuditCheck -CheckName "Environment Contract" -ScriptPath "${scriptDir}\env_contract.ps1" -OutputFile "${auditFolder}\env_contract.txt" -Required $false

# 5) security_audit.ps1
Invoke-AuditCheck -CheckName "Security Audit" -ScriptPath "${scriptDir}\security_audit.ps1" -OutputFile "${auditFolder}\security_audit.txt" -Required $false

# 6) auth_security_check.ps1
Invoke-AuditCheck -CheckName "Auth Security Check" -ScriptPath "${scriptDir}\auth_security_check.ps1" -OutputFile "${auditFolder}\auth_security.txt" -Required $false

# 7) tenant_boundary_check.ps1
Invoke-AuditCheck -CheckName "Tenant Boundary Check" -ScriptPath "${scriptDir}\tenant_boundary_check.ps1" -OutputFile "${auditFolder}\tenant_boundary.txt" -Required $false

# 8) session_posture_check.ps1
Invoke-AuditCheck -CheckName "Session Posture Check" -ScriptPath "${scriptDir}\session_posture_check.ps1" -OutputFile "${auditFolder}\session_posture.txt" -Required $false

# 9) observability_status.ps1
Invoke-AuditCheck -CheckName "Observability Status" -ScriptPath "${scriptDir}\observability_status.ps1" -OutputFile "${auditFolder}\observability_status.txt" -Required $false

# Determine overall status
$overall = "PASS"
$exitCode = 0

if ($hasFail) {
    $overall = "FAIL"
    $exitCode = 1
} elseif ($hasWarn) {
    $overall = "WARN"
    $exitCode = 2
}

# Write summary.json
Write-Host ""
Write-Host "=== Writing Summary ===" -ForegroundColor Cyan
try {
    $summary = @{
        checks = $checks | ForEach-Object {
            @{
                name = $_.name
                status = $_.status
                exit_code = $_.exit_code
                notes = $_.notes
            }
        }
        overall = @{
            status = $overall
            exit_code = $exitCode
        }
    }
    
    $summaryJson = $summary | ConvertTo-Json -Depth 10
    $summaryJson | Out-File -FilePath "${auditFolder}\summary.json" -Encoding UTF8
    Write-Host "  [OK] summary.json" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to write summary: $($_.Exception.Message)" -ForegroundColor Yellow
    $hasWarn = $true
}

# Print results
Write-Host ""
if (Test-Path "${scriptDir}\_lib\ops_output.ps1") {
    Write-Info "=== SELF-AUDIT COMPLETE ==="
} else {
    Write-Host "=== SELF-AUDIT COMPLETE ===" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "AUDIT_PATH=$auditFolder" -ForegroundColor Yellow
Write-Host "AUDIT_OVERALL=$overall" -ForegroundColor $(if ($overall -eq "PASS") { "Green" } elseif ($overall -eq "WARN") { "Yellow" } else { "Red" })

Pop-Location
Invoke-OpsExit $exitCode
return $exitCode

