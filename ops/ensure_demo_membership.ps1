# Ensure Demo Membership (WP-49)
# Guarantees the test user has at least one membership with a valid tenant UUID
# PowerShell 5.1 compatible, ASCII-only outputs

param(
    [string]$HosBaseUrl = "http://localhost:3000",
    [string]$TenantSlug = $null,
    [string]$Email = $null
)

$ErrorActionPreference = "Stop"

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

# Helper: Print sanitized
function Write-Sanitized {
    param([string]$text, [string]$Color = "White")
    $sanitized = Sanitize-Ascii $text
    Write-Host $sanitized -ForegroundColor $Color
}

# Helper: Mask token (show last 6 chars)
function Mask-Token {
    param([string]$token)
    if ($token -and $token.Length -gt 6) {
        return "***" + $token.Substring($token.Length - 6)
    }
    return "***"
}

# Helper: Extract tenant_id robustly from memberships (same as prototype_flow_smoke.ps1)
function Get-TenantIdFromMemberships {
    param([object]$Memberships)
    
    if (-not $Memberships) {
        return $null
    }
    
    # Handle array or object with data/items property
    $membershipsArray = $null
    
    # First check if it's a direct array
    if ($Memberships -is [Array]) {
        $membershipsArray = $Memberships
    }
    # Then check for PSCustomObject with data/items properties
    elseif ($Memberships -is [PSCustomObject]) {
        # Try 'items' first (common HOS API response format)
        if ($Memberships.PSObject.Properties['items'] -and $Memberships.items -is [Array]) {
            $membershipsArray = $Memberships.items
        }
        # Then try 'data'
        elseif ($Memberships.PSObject.Properties['data'] -and $Memberships.data -is [Array]) {
            $membershipsArray = $Memberships.data
        }
    }
    # Fallback: try direct property access (for dynamic objects)
    elseif ($Memberships.items -is [Array]) {
        $membershipsArray = $Memberships.items
    }
    elseif ($Memberships.data -is [Array]) {
        $membershipsArray = $Memberships.data
    }
    
    if (-not $membershipsArray) {
        return $null
    }
    
    if ($membershipsArray.Count -eq 0) {
        # Empty array - no memberships
        return $null
    }
    
    # Iterate all memberships (not just [0])
    foreach ($membership in $membershipsArray) {
        $tenantId = $null
        
        # Try different field paths in order (as specified in requirements)
        # 1) membership.tenant_id
        if ($membership.tenant_id) {
            $tenantId = $membership.tenant_id
        }
        # 2) membership.tenant.id (nested object)
        elseif ($membership.tenant -and $membership.tenant.id) {
            $tenantId = $membership.tenant.id
        }
        # 3) membership.tenant.id (via PSObject.Properties for safety)
        elseif ($membership.tenant -and $membership.tenant.PSObject.Properties['id']) {
            $tenantId = $membership.tenant.id
        }
        # 4) membership.tenantId
        elseif ($membership.tenantId) {
            $tenantId = $membership.tenantId
        }
        # 5) membership.store_tenant_id
        elseif ($membership.store_tenant_id) {
            $tenantId = $membership.store_tenant_id
        }
        
        # Validate UUID format
        if ($tenantId -and $tenantId -is [string] -and $tenantId.Trim().Length -gt 0) {
            $guidResult = [System.Guid]::Empty
            if ([System.Guid]::TryParse($tenantId, [ref]$guidResult)) {
                return $tenantId
            }
        }
    }
    
    return $null
}

Write-Host "=== ENSURE DEMO MEMBERSHIP (WP-49) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Get parameters from env or use defaults
if (-not $TenantSlug) {
    $TenantSlug = $env:TENANT_A_SLUG
    if (-not $TenantSlug) {
        $TenantSlug = "tenant-a"
    }
}

if (-not $Email) {
    $Email = $env:HOS_TEST_EMAIL
    if (-not $Email) {
        $Email = "testuser@example.com"
    }
}

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  H-OS URL: $HosBaseUrl" -ForegroundColor Gray
Write-Host "  Tenant Slug: $TenantSlug" -ForegroundColor Gray
Write-Host "  Email: $Email" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

# Step 1: Acquire JWT using existing helper
Write-Host "[1] Acquiring JWT token..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot\_lib\test_auth.ps1"
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) {
        $apiKey = "dev-api-key"
    }
    $jwtToken = Get-DevTestJwtToken -HosBaseUrl $HosBaseUrl -TenantSlug $TenantSlug -Email $Email -HosApiKey $apiKey
    if (-not $jwtToken) {
        throw "Failed to obtain JWT token"
    }
    $tokenMask = Mask-Token $jwtToken
    Write-Host "PASS: Token acquired ($tokenMask)" -ForegroundColor Green
} catch {
    Write-Sanitized "FAIL: JWT token acquisition failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
    exit 1
}

# Step 2: Check existing memberships
Write-Host ""
Write-Host "[2] Checking existing memberships..." -ForegroundColor Yellow
try {
    $membershipsResponse = Invoke-RestMethod -Uri "$HosBaseUrl/v1/me/memberships" `
        -Headers @{ "Authorization" = "Bearer $jwtToken" } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    
    if ($tenantId) {
        Write-Host "PASS: User already has membership with tenant_id: $tenantId" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "  No valid tenant_id found in memberships, bootstrapping..." -ForegroundColor Yellow
    }
} catch {
    Write-Sanitized "FAIL: Memberships check failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
    exit 1
}

# Step 3: Bootstrap membership using admin endpoint
Write-Host ""
Write-Host "[3] Bootstrapping membership via admin API..." -ForegroundColor Yellow
try {
    $apiKey = $env:HOS_API_KEY
    if (-not $apiKey) {
        $apiKey = "dev-api-key"
    }
    
    $upsertBody = @{
        tenantSlug = $TenantSlug
        userEmail = $Email
        role = "owner"
    } | ConvertTo-Json
    
    $upsertRequest = Invoke-WebRequest -Uri "$HosBaseUrl/v1/admin/memberships/upsert" `
        -Method Post `
        -Body $upsertBody `
        -ContentType "application/json" `
        -Headers @{
            "x-hos-api-key" = $apiKey
        } `
        -TimeoutSec 10 `
        -ErrorAction Stop
    
    $upsertResponse = $upsertRequest.Content | ConvertFrom-Json
    
    if (-not $upsertResponse.tenant_id) {
        throw "Admin upsert response missing tenant_id"
    }
    
    $tenantId = $upsertResponse.tenant_id
    Write-Host "PASS: Membership bootstrapped successfully" -ForegroundColor Green
    Write-Host "  tenant_id: $tenantId" -ForegroundColor Gray
    Write-Host "  tenant_slug: $($upsertResponse.tenant_slug)" -ForegroundColor Gray
    Write-Host "  role: $($upsertResponse.role)" -ForegroundColor Gray
} catch {
    $statusCode = $null
    $responseBody = $null
    
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode.value__
        try {
            $responseStream = $_.Exception.Response.GetResponseStream()
            if ($responseStream) {
                $reader = New-Object System.IO.StreamReader($responseStream)
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                $responseStream.Close()
            }
        } catch {
            if ($_.ErrorDetails.Message) {
                $responseBody = $_.ErrorDetails.Message
            }
        }
    }
    
    Write-Host "FAIL: Membership bootstrap failed" -ForegroundColor Red
    if ($statusCode) {
        Write-Host "  Status: $statusCode" -ForegroundColor Yellow
    }
    
    if ($responseBody) {
        try {
            $errorObj = $responseBody | ConvertFrom-Json
            if ($errorObj.error) {
                $errorData = $errorObj.error
                if ($errorData.fieldErrors) {
                    Write-Host "  Field Errors:" -ForegroundColor Yellow
                    $errorData.fieldErrors.PSObject.Properties | ForEach-Object {
                        $valueStr = if ($_.Value -is [Array]) { $_.Value -join ', ' } else { $_.Value.ToString() }
                        Write-Host "    $($_.Name): $valueStr" -ForegroundColor Gray
                    }
                }
                if ($errorData.message) {
                    Write-Host "  Message: $($errorData.message)" -ForegroundColor Yellow
                }
            } elseif ($errorObj.message) {
                Write-Host "  Message: $($errorObj.message)" -ForegroundColor Yellow
            }
        } catch {
            $sanitized = $responseBody -replace '[^\x00-\x7F]', ''
            $preview = if ($sanitized.Length -gt 200) { $sanitized.Substring(0, 200) + "..." } else { $sanitized }
            Write-Host "  Response: $preview" -ForegroundColor Yellow
        }
    } else {
        $errorMsg = $_.Exception.Message
        $sanitized = Sanitize-Ascii $errorMsg
        Write-Host "  Error: $sanitized" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "  Remediation:" -ForegroundColor Yellow
    if ($statusCode -eq 401) {
        Write-Host "    API key mismatch. Set HOS_API_KEY environment variable:" -ForegroundColor Yellow
        Write-Host "      `$env:HOS_API_KEY = 'your-api-key'" -ForegroundColor Gray
    } elseif ($statusCode -eq 404) {
        Write-Host "    Tenant or user not found. Ensure:" -ForegroundColor Yellow
        Write-Host "      - Tenant '$TenantSlug' exists (or create via /v1/admin/users/upsert)" -ForegroundColor Gray
        Write-Host "      - User '$Email' exists (create via /v1/admin/users/upsert first)" -ForegroundColor Gray
    } else {
        Write-Host "    Check H-OS service status: docker compose ps" -ForegroundColor Yellow
        Write-Host "    Verify endpoint: $HosBaseUrl/v1/admin/memberships/upsert" -ForegroundColor Yellow
    }
    
    $hasFailures = $true
    exit 1
}

# Step 4: Verify membership was created
Write-Host ""
Write-Host "[4] Verifying membership..." -ForegroundColor Yellow
try {
    $membershipsResponse = Invoke-RestMethod -Uri "$HosBaseUrl/v1/me/memberships" `
        -Headers @{ "Authorization" = "Bearer $jwtToken" } `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    $tenantId = Get-TenantIdFromMemberships -Memberships $membershipsResponse
    
    if ($tenantId) {
        Write-Host "PASS: Membership verified, tenant_id: $tenantId" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Membership created but tenant_id not found in response" -ForegroundColor Red
        $hasFailures = $true
        exit 1
    }
} catch {
    Write-Sanitized "FAIL: Membership verification failed: $($_.Exception.Message)" "Red"
    $hasFailures = $true
    exit 1
}

Write-Host ""
Write-Host "=== ENSURE DEMO MEMBERSHIP: PASS ===" -ForegroundColor Green
exit 0

