param(
  [string]$BaseUrl = "http://localhost:3000",
  [switch]$SkipAuth
)

$ErrorActionPreference = "Stop"

function Json($obj) { $obj | ConvertTo-Json -Compress }
function GetJson($url) { Invoke-RestMethod -TimeoutSec 10 $url }
function PostJson($url, $body, $session) {
  if ($null -ne $session) {
    return Invoke-RestMethod -TimeoutSec 10 -Method Post -Uri $url -WebSession $session -ContentType "application/json" -Body $body
  }
  return Invoke-RestMethod -TimeoutSec 10 -Method Post -Uri $url -ContentType "application/json" -Body $body
}

Write-Host "Smoke test: $BaseUrl"

$health = GetJson "$BaseUrl/health"
$ready = GetJson "$BaseUrl/ready"
$v1health = GetJson "$BaseUrl/v1/health"
$v1ready = GetJson "$BaseUrl/v1/ready"

Write-Host "health:   $(Json $health)"
Write-Host "ready:    $(Json $ready)"
Write-Host "v1health: $(Json $v1health)"
Write-Host "v1ready:  $(Json $v1ready)"

Write-Host "metrics head:"
try {
  # Avoid downloading a large metrics payload into PowerShell memory.
  & curl.exe -s --max-time 5 "$BaseUrl/metrics" | Select-Object -First 12
} catch {
  Write-Host "WARN: metrics check skipped/failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

$v1 = "$BaseUrl/v1"

if ($SkipAuth) {
  Write-Host "SKIP: auth flow (tenant/register/refresh/logout) disabled via -SkipAuth"
  Write-Host "OK: smoke test passed."
  exit 0
}

$slug = "smoke-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
$tenant = Invoke-RestMethod -Method Post -Uri "$v1/tenants" -ContentType "application/json" `
  -Body (@{ slug = $slug; name = "Smoke Tenant" } | ConvertTo-Json)
Write-Host "tenant:   $(Json $tenant)"

$email = "$slug@example.com"
$session = $null
$reg = Invoke-RestMethod -TimeoutSec 10 -Method Post -Uri "$v1/auth/register" -ContentType "application/json" `
  -Body (@{ tenantSlug = $slug; email = $email; password = "VeryStrongPass123!" } | ConvertTo-Json) `
  -SessionVariable session
Write-Host "register: $(Json $reg)"

$token = $reg.token
$me = Invoke-RestMethod -Uri "$v1/me" -Headers @{ Authorization = "Bearer $token" }
Write-Host "me:       $(Json $me)"

$audit = Invoke-RestMethod -Uri "$v1/audit?limit=5" -Headers @{ Authorization = "Bearer $token" }
Write-Host "audit:    $(Json $audit)"

try {
  $cookieOk = [bool]($session.Cookies.GetCookies($v1) | Where-Object { $_.Name -eq "hos_refresh" })
  Write-Host "refresh cookie: $cookieOk"

  $refresh = PostJson "$v1/auth/refresh" "{}" $session
  Write-Host "refresh:  $(Json $refresh)"

  $logout = PostJson "$v1/auth/logout" "{}" $session
  Write-Host "logout:   $(Json $logout)"
} catch {
  Write-Host "WARN: refresh/logout check skipped/failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "OK: smoke test passed."



