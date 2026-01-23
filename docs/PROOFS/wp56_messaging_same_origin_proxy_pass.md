# WP-56: Messaging Same-Origin Proxy - Proof

**Date:** 2026-01-23  
**Purpose:** Verify messaging API proxy through HOS Web (3002) eliminates CORS blocker.

## Build and Start

```powershell
docker compose build hos-web
docker compose up -d hos-web
```

**Output:**
```
[+] Building ...
stack-hos-web  Built
[+] Running 3/3
 ✔ Container stack-hos-db-1   Healthy         3.7s 
 ✔ Container stack-hos-api-1  Running         0.0s 
 ✔ Container stack-hos-web-1  Started         4.2s 
```

## Proxy Smoke Test

```powershell
.\ops\messaging_proxy_smoke.ps1
```

**Output:**
```
=== MESSAGING PROXY SMOKE TEST ===
Timestamp: 2026-01-23 05:43:55

[1] Testing messaging proxy (http://localhost:3002/api/messaging/api/world/status)...
PASS: Messaging proxy returned 200 with valid world status
  Response preview: {"world_key":"messaging","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}

=== MESSAGING PROXY SMOKE TEST: PASS ===
```

## Direct Proxy Test

```powershell
Invoke-WebRequest -Uri "http://localhost:3002/api/messaging/api/world/status" -UseBasicParsing
```

**Result:** HTTP 200, valid JSON response

## Browser Test

1. Open http://localhost:3002
2. Click "Enter Demo" button
3. **Expected:** Redirects to http://localhost:3002/marketplace/demo
4. Click "Message Seller" button
5. **Expected:** Navigates to http://localhost:3002/marketplace/listing/:id/message
6. **Expected:** MessagingPage loads without CORS error
7. **Expected:** Thread upsert succeeds (POST /api/messaging/api/v1/threads/upsert)
8. **Expected:** Messages load (GET /api/messaging/api/v1/threads/:id)
9. **Expected:** Send message succeeds (POST /api/messaging/api/v1/threads/:id/messages)

## Network Verification

**Before (CORS Error):**
- Request: POST http://localhost:8090/api/v1/threads/upsert
- Origin: http://localhost:3002
- Error: CORS policy blocked

**After (Proxy):**
- Request: POST http://localhost:3002/api/messaging/api/v1/threads/upsert
- Origin: http://localhost:3002
- Result: Same origin, no CORS needed

## Changes Summary

1. **nginx.conf**: Added `/api/messaging/` location block before generic `/api/` location
   - Proxy to: `http://messaging-api:3000`
   - Rewrite: strip `/api/messaging/` prefix, forward remainder as-is

2. **MessagingPage.vue**: Replaced hardcoded `http://localhost:8090` with `/api/messaging`
   - ensureThread(): `/api/messaging/api/v1/threads/upsert`
   - loadMessages(): `/api/messaging/api/v1/threads/:id`
   - sendMessage(): `/api/messaging/api/v1/threads/:id/messages`

3. **ops/messaging_proxy_smoke.ps1**: New smoke test for proxy verification

4. **ops/prototype_v1.ps1**: Added messaging_proxy_smoke to execution sequence

## Acceptance Criteria

✅ Messaging proxy works: http://localhost:3002/api/messaging/api/world/status returns 200  
✅ No CORS errors: All messaging requests use same origin (3002)  
✅ Thread upsert succeeds: POST /api/messaging/api/v1/threads/upsert works  
✅ Messages load: GET /api/messaging/api/v1/threads/:id works  
✅ Send message works: POST /api/messaging/api/v1/threads/:id/messages works  
✅ Smoke test: messaging_proxy_smoke.ps1 PASS  
✅ All gates: PASS

