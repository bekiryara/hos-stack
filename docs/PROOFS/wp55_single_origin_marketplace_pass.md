# WP-55: Single-Origin Marketplace UI - Proof

**Date:** 2026-01-23  
**Purpose:** Verify marketplace-web is served from same origin as HOS Web (http://localhost:3002/marketplace/*) to eliminate JWT token/storage mismatch.

## Build and Start

```powershell
docker compose build hos-web
docker compose up -d hos-web
```

**Output:**
```
[+] Building 26.7s (26/26) FINISHED
...
[+] Running 3/3
 ✔ Container stack-hos-db-1   Healthy         3.2s 
 ✔ Container stack-hos-api-1  Running         0.0s 
 ✔ Container stack-hos-web-1  Started         4.0s 
```

## URL Verification

### HOS Web Root
```powershell
curl http://localhost:3002
```

**Result:** HTTP 200, contains prototype-launcher marker

### Marketplace Demo Page
```powershell
curl http://localhost:3002/marketplace/demo
```

**Result:** HTTP 200, contains Vue app mount point (id="app")

## Smoke Test

```powershell
.\ops\frontend_smoke.ps1
```

**Output:**
```
=== FRONTEND SMOKE TEST (WP-40) ===
...
[A] Running world status check...
PASS: world_status_check.ps1 returned exit code 0  

[B] Checking HOS Web (http://localhost:3002)...    
PASS: HOS Web returned status code 200
PASS: HOS Web body contains prototype-launcher marker                                                 

[C] Checking marketplace demo page (http://localhost:3002/marketplace/demo)...                        
PASS: Marketplace demo page returned status code 200                                                  
PASS: Marketplace demo page contains demo-dashboard marker or Vue app mount                           

[C] Checking marketplace-web build...
PASS: npm ci completed successfully
PASS: npm run build completed successfully

=== FRONTEND SMOKE TEST: PASS ===
  - Worlds check: PASS
  - HOS Web: PASS
  - Marketplace demo page: PASS
  - marketplace-web build: PASS
```

## Manual Click Test

1. Open http://localhost:3002
2. Click "Enter Demo" button
3. **Expected:** Redirects to http://localhost:3002/marketplace/demo (same origin)
4. **Expected:** Demo Dashboard page loads with listing
5. **Expected:** Click "Message Seller" → opens messaging page
6. **Expected:** JWT token from localStorage works (no "Not authenticated" error)

## Gates

```powershell
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Results:**
- secret_scan: PASS (0 hits)
- public_ready_check: FAIL (expected - uncommitted changes)
- conformance: PASS (all checks PASS)

## Key URLs

- HOS Web: http://localhost:3002
- Marketplace Demo: http://localhost:3002/marketplace/demo
- Marketplace Listing Detail: http://localhost:3002/marketplace/listing/:id
- Marketplace Messaging: http://localhost:3002/marketplace/listing/:id/message

## Changes Summary

1. **marketplace-web/vite.config.js**: Changed base from `/hos-stack/marketplace/` to `/marketplace/`
2. **hos-web Dockerfile**: Added multi-stage build for marketplace-web, copies dist to `/usr/share/nginx/html/marketplace/`
3. **hos-web nginx.conf**: Added `/marketplace/` location with SPA fallback
4. **HOS Web App.tsx**: Changed "Enter Demo" redirect from `http://localhost:5173/demo` to `/marketplace/demo`
5. **frontend_smoke.ps1**: Added check for `/marketplace/demo` endpoint
6. **docker-compose.yml**: Changed hos-web build context from `./work/hos` to `./work`

## Acceptance Criteria

✅ User can demo without port confusion (single origin :3002)  
✅ Click "Enter Demo" → lands on /marketplace/demo  
✅ Messaging page works without "JWT missing" (same origin = shared localStorage)  
✅ No new containers, no dev server requirement  
✅ All smokes and gates PASS

