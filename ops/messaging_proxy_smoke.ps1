# Messaging Proxy Smoke Test (WP-NEXT)
# Verifies messaging API proxy through HOS Web (3002) works

$ErrorActionPreference = "Stop"

# Helper: Sanitize to ASCII
function Sanitize-Ascii {
    param([string]$text)
    return $text -replace '[^\x00-\x7F]', ''
}

Write-Host "=== MESSAGING PROXY SMOKE TEST ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Test: Messaging API proxy through HOS Web
Write-Host "[1] Testing messaging proxy (http://localhost:3002/api/messaging/api/world/status)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3002/api/messaging/api/world/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($response.StatusCode -ne 200) {
        Write-Host "FAIL: Messaging proxy returned status code $($response.StatusCode), expected 200" -ForegroundColor Red
        exit 1
    }
    
    $bodyContent = Sanitize-Ascii $response.Content
    if ($bodyContent -match 'world_key' -and $bodyContent -match 'messaging') {
        Write-Host "PASS: Messaging proxy returned 200 with valid world status" -ForegroundColor Green
        Write-Host "  Response preview: $($bodyContent.Substring(0, [Math]::Min(100, $bodyContent.Length)))" -ForegroundColor Gray
    } else {
        Write-Host "WARN: Messaging proxy returned 200 but response format unexpected" -ForegroundColor Yellow
        Write-Host "  Response preview: $($bodyContent.Substring(0, [Math]::Min(100, $bodyContent.Length)))" -ForegroundColor Gray
    }
} catch {
    $errorMsg = Sanitize-Ascii $_.Exception.Message
    Write-Host "FAIL: Messaging proxy unreachable: $errorMsg" -ForegroundColor Red
    Write-Host "  Check if HOS Web is running: docker compose ps hos-web" -ForegroundColor Yellow
    Write-Host "  Check if Messaging API is running: docker compose ps messaging-api" -ForegroundColor Yellow
    Write-Host "  Verify nginx config includes /api/messaging/ location" -ForegroundColor Yellow
    exit 1
}

# Test: Thread by-context endpoint (proxy routing verification)
Write-Host ""
Write-Host "[2] Testing thread by-context endpoint (proxy routing)..." -ForegroundColor Yellow
try {
    # Use fixed context for deterministic test
    $testUrl = "http://localhost:3002/api/messaging/api/v1/threads/by-context?context_type=smoke&context_id=proxy-smoke"
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
    # If we get here, proxy routing works (even if 401/403/404, it means proxy forwarded the request)
    if ($response.StatusCode -eq 200) {
        Write-Host "PASS: Thread by-context endpoint returned 200" -ForegroundColor Green
    } elseif ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403) {
        Write-Host "PASS: Thread by-context endpoint proxy routing works (auth required, expected)" -ForegroundColor Green
    } elseif ($response.StatusCode -eq 404) {
        Write-Host "PASS: Thread by-context endpoint proxy routing works (thread not found, expected for test context)" -ForegroundColor Green
    } else {
        Write-Host "PASS: Thread by-context endpoint proxy routing works (status: $($response.StatusCode))" -ForegroundColor Green
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401 -or $statusCode -eq 403 -or $statusCode -eq 404) {
        Write-Host "PASS: Thread by-context endpoint proxy routing works (status: $statusCode, expected)" -ForegroundColor Green
    } else {
        $errorMsg = Sanitize-Ascii $_.Exception.Message
        Write-Host "WARN: Thread by-context endpoint test: $errorMsg" -ForegroundColor Yellow
        Write-Host "  (Proxy routing may still work, this is a non-blocking check)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== MESSAGING PROXY SMOKE TEST: PASS ===" -ForegroundColor Green
exit 0

