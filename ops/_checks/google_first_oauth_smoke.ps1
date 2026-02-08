<# 
  google_first_oauth_smoke.ps1
  Goal: Lock down Google-first public customer flow without interactive login.
  - Ensures Marketplace can receive token handoff route.
  - Ensures HOS Google OAuth start defaults to public mode (tenantSlug optional).
  PowerShell 5.1 compatible.
#>

$ErrorActionPreference = "Stop"

Write-Host "=== GOOGLE-FIRST OAUTH SMOKE ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$hasFailures = $false

function Fail([string]$msg) {
  Write-Host ("FAIL: {0}" -f $msg) -ForegroundColor Red
  $script:hasFailures = $true
}

function Pass([string]$msg) {
  Write-Host ("PASS: {0}" -f $msg) -ForegroundColor Green
}

# [A] Marketplace route exists (token handoff landing)
Write-Host "[A] Checking Marketplace OAuth complete route..." -ForegroundColor Yellow
try {
  $resp = Invoke-WebRequest -Uri "http://localhost:3002/marketplace/oauth/complete" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
  if ([int]$resp.StatusCode -eq 200) { Pass "Marketplace /marketplace/oauth/complete returns 200" }
  else { Fail "Marketplace /marketplace/oauth/complete returned $([int]$resp.StatusCode), expected 200" }
} catch {
  Fail "Marketplace /marketplace/oauth/complete unreachable: $($_.Exception.Message)"
}

# [B] HOS Google start defaults to public mode (no tenantSlug) and issues public-mode cookies
Write-Host ""
Write-Host "[B] Checking HOS Google start default public mode..." -ForegroundColor Yellow

$statusCode = $null
$headers = $null
$respObj = $null
try {
  # Use HttpWebRequest to reliably disable auto-redirect on Windows PowerShell 5.1
  $req = [System.Net.HttpWebRequest]::Create("http://localhost:3000/v1/auth/google/start")
  $req.Method = "GET"
  $req.AllowAutoRedirect = $false
  $req.Timeout = 10000
  $req.Accept = "text/html"
  try {
    $respObj = $req.GetResponse()
  } catch [System.Net.WebException] {
    # For 302, .NET throws WebException; response still contains headers/status.
    $respObj = $_.Exception.Response
  }

  if ($respObj) {
    $statusCode = [int]$respObj.StatusCode
    $headers = $respObj.Headers
  } else {
    Fail "HOS /v1/auth/google/start returned no response object"
  }
} catch {
  Fail "HOS /v1/auth/google/start request failed: $($_.Exception.Message)"
} finally {
  try { if ($respObj) { $respObj.Close() } } catch {}
}

if ($statusCode -eq 302 -or $statusCode -eq 303) {
  Pass "HOS /v1/auth/google/start returned $statusCode (redirect expected)"
} else {
  Fail "HOS /v1/auth/google/start returned $statusCode, expected 302/303"
}

if ($headers) {
  $location = $headers["Location"]
  if ($location -and ($location -like "https://accounts.google.com/*")) {
    Pass "Redirect location is Google accounts"
  } else {
    Fail "Redirect location is missing or not Google accounts (Location=$location)"
  }

  $setCookie = $headers["Set-Cookie"]
  $setCookieText = ""
  if ($setCookie -is [System.Array]) { $setCookieText = ($setCookie -join "`n") }
  else { $setCookieText = [string]$setCookie }

  if ($setCookieText -match "hos_oauth_mode=public") { Pass "hos_oauth_mode=public cookie set" }
  else { Fail "hos_oauth_mode=public cookie missing" }

  if ($setCookieText -match "hos_oauth_tenant=public") { Pass "hos_oauth_tenant=public cookie set" }
  else { Fail "hos_oauth_tenant=public cookie missing" }
}

Write-Host ""
if ($hasFailures) {
  Write-Host "=== GOOGLE-FIRST OAUTH SMOKE: FAIL ===" -ForegroundColor Red
  exit 1
} else {
  Write-Host "=== GOOGLE-FIRST OAUTH SMOKE: PASS ===" -ForegroundColor Green
  exit 0
}

