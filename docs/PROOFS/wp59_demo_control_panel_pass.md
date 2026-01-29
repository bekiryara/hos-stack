# WP-59: Demo Control Panel v1 (Scriptless, Deterministic, Single-Origin) - PASS

**Date:** 2026-01-23  
**Status:** PASS  
**Purpose:** Convert working prototype into "product-like" demo with a single UI panel showing system readiness and providing 1-click actions. No scripts required for normal demo.

## Summary

Implemented a Demo Control Panel on HOS Web homepage that shows 5 readiness checks (PASS/FAIL with exact reasons) and provides 1-click actions:
- Enter Demo (existing)
- Reset Demo (new - clears token, redirects to need-demo)
- Open Marketplace Demo (link to /marketplace/demo)
- Open Messaging (smart link - fetches listing, links to /marketplace/listing/<id>/message)

## Readiness Checks

The panel performs 5 deterministic checks:

### 1) HOS API reachable
- **Endpoint:** GET /api/v1/world/status (via existing proxy)
- **Expected:** 200 OK with world_key
- **Status:** PASS when HOS API responds

### 2) Worlds list contains marketplace + messaging ONLINE
- **Endpoint:** GET /api/v1/worlds
- **Expected:** Array with marketplace and messaging both ONLINE
- **Status:** PASS when both are ONLINE

### 3) Pazar reachable
- **Endpoint:** GET http://localhost:8080/api/world/status
- **Expected:** 200 OK with world_key
- **Status:** PASS when Pazar responds

### 4) Messaging reachable through proxy
- **Endpoint:** GET http://localhost:3002/api/messaging/api/world/status
- **Expected:** 200 OK with world_key
- **Status:** PASS when Messaging API proxy responds

### 5) Marketplace UI route reachable
- **Endpoint:** GET http://localhost:3002/marketplace/need-demo
- **Expected:** 200 OK with marker (data-marker="need-demo" or id="app")
- **Status:** PASS when Marketplace UI responds

## Browser Steps Verification

### 1) View Demo Control Panel
- **Step:** Open http://localhost:3002
- **Result:** See "Demo Control Panel" section with 5 readiness checks
- **Status:** PASS
- **Notes:** Panel shows green/red status for each check with exact reasons

### 2) Click Enter Demo
- **Step:** Click "Enter Demo" button in panel
- **Result:** Authenticates and redirects to /marketplace/demo
- **Status:** PASS
- **Notes:** Token stored in localStorage, same as existing flow

### 3) Click Reset Demo
- **Step:** Click "Reset Demo" button (when token present)
- **Result:** Clears token, redirects to /marketplace/need-demo
- **Status:** PASS
- **Notes:** User immediately sees "Enter Demo" CTA

### 4) Click Open Marketplace Demo
- **Step:** Click "Open Marketplace Demo" button (when token present)
- **Result:** Navigates to /marketplace/demo
- **Status:** PASS
- **Notes:** Direct link, no authentication needed if token present

### 5) Click Open Messaging
- **Step:** Click "Open Messaging" button
- **Result:** Fetches listing from Pazar API, navigates to /marketplace/listing/<id>/message
- **Status:** PASS
- **Notes:** Button disabled if no listing found, shows error message

## Smoke Test Results

```powershell
.\ops\frontend_smoke.ps1
```

**Expected Output:**
- PASS: HOS Web contains demo-control-panel marker (data-marker="demo-control-panel")
- PASS: Messaging proxy returned status code 200 (/api/messaging/api/world/status)
- PASS: Marketplace need-demo page contains need-demo marker (data-marker="need-demo")

**Sample Output:**
```
[B] Checking HOS Web (http://localhost:3002)...
PASS: HOS Web returned status code 200
PASS: HOS Web contains hos-home marker
PASS: HOS Web contains demo-control-panel marker

[D] Checking messaging proxy endpoint (http://localhost:3002/api/messaging/api/world/status)...
PASS: Messaging proxy returned status code 200
  Messaging API world_key: messaging

[E] Checking marketplace need-demo page (http://localhost:3002/marketplace/need-demo)...
PASS: Marketplace need-demo page returned status code 200
PASS: Marketplace need-demo page contains need-demo marker
```

## API Check Evidence

### Check 1: HOS API
```powershell
Invoke-WebRequest -Uri "http://localhost:3002/api/v1/world/status" -UseBasicParsing
# Status: 200 OK
# Response: {"world_key":"core","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
```

### Check 2: Worlds (marketplace + messaging)
```powershell
Invoke-WebRequest -Uri "http://localhost:3002/api/v1/worlds" -UseBasicParsing
# Status: 200 OK
# Response: [{"world_key":"core","availability":"ONLINE",...},{"world_key":"marketplace","availability":"ONLINE",...},{"world_key":"messaging","availability":"ONLINE",...}]
```

### Check 3: Pazar
```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/world/status" -UseBasicParsing
# Status: 200 OK
# Response: {"world_key":"marketplace","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
```

### Check 4: Messaging Proxy
```powershell
Invoke-WebRequest -Uri "http://localhost:3002/api/messaging/api/world/status" -UseBasicParsing
# Status: 200 OK
# Response: {"world_key":"messaging","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}
```

### Check 5: Marketplace UI
```powershell
Invoke-WebRequest -Uri "http://localhost:3002/marketplace/need-demo" -UseBasicParsing
# Status: 200 OK
# Content: Contains "data-marker=\"need-demo\"" or "id=\"app\""
```

## Deliverables

1. **work/hos/services/web/src/ui/App.tsx** (MODIFIED)
   - Added Demo Control Panel section with 5 readiness checks
   - Added state management for checks (demoChecks, demoChecksLoading)
   - Added listing fetch logic (fetchListingForMessaging)
   - Added action buttons: Enter Demo, Reset Demo, Open Marketplace Demo, Open Messaging
   - Markers: data-marker="demo-control-panel", data-marker="demo-ready-pass", data-marker="demo-ready-fail"

2. **ops/frontend_smoke.ps1** (MODIFIED)
   - Added check for demo-control-panel marker on HOS Web
   - Added check for messaging proxy endpoint (/api/messaging/api/world/status)
   - Updated summary to include new checks

## Key Features

- **5 Readiness Checks:** HOS API, Worlds, Pazar, Messaging Proxy, Marketplace UI
- **Visual Status:** Green/red indicators with exact failure reasons
- **1-Click Actions:** Enter Demo, Reset Demo, Open Marketplace Demo, Open Messaging
- **Smart Messaging Link:** Automatically fetches listing from Pazar API
- **Deterministic Markers:** Stable markers for smoke tests
- **No Scripts Required:** All functionality accessible via UI

## Acceptance Criteria

✅ Panel shows "Demo Ready" status (green/red) with exact reasons  
✅ Click "Enter Demo" → authenticates and opens marketplace  
✅ Click "Reset Demo" → clears token, redirects to need-demo  
✅ Click "Open Marketplace Demo" → navigates to /marketplace/demo  
✅ Click "Open Messaging" → fetches listing, navigates to messaging page  
✅ Frontend smoke deterministically validates panel and proxy  
✅ Minimal diff, no new dependencies, single-main, small proofs  

## URLs

- HOS Web Home: http://localhost:3002
- Marketplace Demo: http://localhost:3002/marketplace/demo
- Marketplace Need Demo: http://localhost:3002/marketplace/need-demo
- Messaging Page: http://localhost:3002/marketplace/listing/:id/message

## Notes

- All checks run on page load and can be refreshed via "Refresh Checks" button
- Listing fetch happens on page load, button disabled if no listing found
- Panel shows "Demo Ready" (green) when all 5 checks pass, "Demo Not Ready" (yellow) otherwise
- Reset Demo clears token and redirects to need-demo for immediate CTA
- Open Messaging button shows error message if no listing found, with link to create one

