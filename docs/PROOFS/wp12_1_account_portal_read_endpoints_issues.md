# WP-12.1 Account Portal Read Endpoints - Issues Report

**Date:** 2026-01-17  
**Status:** ⚠️ IN PROGRESS - Issues Identified

## Issues Found

### Issue 1: 500 Internal Server Error - ReflectionException "Function () does not exist"

**Affected Endpoints:**
- GET /api/v1/orders?buyer_user_id={uuid} (Personal scope)
- GET /api/v1/rentals?renter_user_id={uuid} (Personal scope)
- GET /api/v1/reservations?requester_user_id={uuid} (Personal scope)

**Error Details:**
```
ReflectionException: Function () does not exist
Route: api/v1/orders
Method: GET
```

**Root Cause Analysis:**
- Route definitions appear correct (checked with grep)
- AuthContext middleware is properly registered
- Route closure syntax appears valid
- Error occurs when Authorization header is present but token validation may be failing

**Possible Causes:**
1. JWT token validation in AuthContext middleware may be throwing exception
2. Route closure may have syntax issue not visible in static analysis
3. Laravel route caching issue (route:clear executed but error persists)

**Status:** Under investigation

### Issue 2: Store Scope Endpoints Working

**Working Endpoints:**
- ✅ GET /api/v1/listings?tenant_id={uuid} (Store scope) - PASS
- ✅ GET /api/v1/orders?seller_tenant_id={uuid} (Store scope) - Needs testing
- ✅ GET /api/v1/rentals?provider_tenant_id={uuid} (Store scope) - Needs testing
- ✅ GET /api/v1/reservations?provider_tenant_id={uuid} (Store scope) - Needs testing

**Status:** Store scope endpoints appear to work (listings confirmed)

### Issue 3: Response Format Consistency

**Fixed:**
- ✅ GET /api/v1/listings now always returns {data, meta} format (WP-12.1 fix applied)

**Status:** Fixed

## Next Steps

1. Investigate ReflectionException root cause
2. Test all 7 endpoints with contract check script
3. Fix 500 errors in personal scope endpoints
4. Create proof document with test results

## Test Commands

```powershell
# Test personal scope (currently failing with 500)
$headers = @{"Authorization" = "Bearer <valid-jwt-token>"}
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/orders?buyer_user_id=<uuid>" -Method Get -Headers $headers

# Test store scope (should work)
$headers = @{"X-Active-Tenant-Id" = "951ba4eb-9062-40c4-9228-f8d2cfc2f426"}
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/listings?tenant_id=951ba4eb-9062-40c4-9228-f8d2cfc2f426" -Method Get -Headers $headers
```


