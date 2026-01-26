# WP-68: User → Tenant Binding Hardening Test Script
# Tests the hardened user-to-tenant binding flow

Write-Host "`n=== WP-68 Hardening Test ===" -ForegroundColor Cyan

# Check if frontend is running
Write-Host "`n1. Checking frontend (localhost:3002)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3002" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
    Write-Host "   ✅ Frontend is running" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Frontend is NOT running" -ForegroundColor Red
    Write-Host "   Start with: cd work/marketplace-web && npm run dev" -ForegroundColor Yellow
    exit 1
}

# Check if backend API is running
Write-Host "`n2. Checking backend API (localhost:3000)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
    Write-Host "   ✅ Backend API is running" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Backend API health check failed (might still be OK)" -ForegroundColor Yellow
}

# Check Docker containers
Write-Host "`n3. Checking Docker containers..." -ForegroundColor Yellow
$containers = docker ps --format "{{.Names}}" 2>$null
if ($containers -match "hos-api|pazar") {
    Write-Host "   ✅ Docker containers are running" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Some Docker containers might not be running" -ForegroundColor Yellow
}

# Test instructions
Write-Host "`n=== Manual Test Steps ===" -ForegroundColor Cyan
Write-Host "`n1. Open browser: http://localhost:3002/marketplace/register" -ForegroundColor White
Write-Host "   → Register a new user" -ForegroundColor Gray
Write-Host "`n2. Navigate to: http://localhost:3002/marketplace/account" -ForegroundColor White
Write-Host "   → Check 'Firma Durumu' card is visible" -ForegroundColor Gray
Write-Host "   → Check 'Firma Oluştur' button is visible (if no firm)" -ForegroundColor Gray
Write-Host "`n3. Click 'Firma Oluştur' button" -ForegroundColor White
Write-Host "   → Should navigate to /marketplace/firm/register" -ForegroundColor Gray
Write-Host "   → Form should be visible (firm_name, firm_owner_name)" -ForegroundColor Gray
Write-Host "`n4. Fill form and submit:" -ForegroundColor White
Write-Host "   - firm_name: 'Test Firma'" -ForegroundColor Gray
Write-Host "   - firm_owner_name: 'Test Owner'" -ForegroundColor Gray
Write-Host "   → Should show success message" -ForegroundColor Gray
Write-Host "   → Should redirect to /demo after ~1.5 seconds" -ForegroundColor Gray
Write-Host "`n5. Check /demo page:" -ForegroundColor White
Write-Host "   → Active tenant should be visible" -ForegroundColor Gray
Write-Host "   → 'No Active Tenant' message should NOT appear" -ForegroundColor Gray
Write-Host "`n6. Check browser console (F12):" -ForegroundColor White
Write-Host "   → No errors should be present" -ForegroundColor Gray
Write-Host "`n7. Check Network tab (F12 > Network):" -ForegroundColor White
Write-Host "   → GET /v1/me → 200 OK" -ForegroundColor Green
Write-Host "   → GET /v1/me/memberships → 200 OK" -ForegroundColor Green
Write-Host "   → POST /v1/tenants/v2 → 200 OK" -ForegroundColor Green

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "If all steps pass, WP-68 hardening is successful! ✅" -ForegroundColor Green

