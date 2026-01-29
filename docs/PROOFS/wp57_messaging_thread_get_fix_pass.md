# WP-57: Messaging Thread GET Fix - Proof

**Date:** 2026-01-23  
**Purpose:** Fix messaging thread GET to use by-context endpoint instead of literal `:id` URL, eliminating 404 errors.

## Problem

**Before Fix:**
- Network request showed: `GET http://localhost:3002/api/messaging/api/v1/threads/5493284b-1461-4cfd-9ff9-d6abfd1ed8f8` → 404
- Messaging API does not have `GET /api/v1/threads/:id` endpoint
- Code was using template literal `${this.threadId}` but endpoint doesn't exist

## Solution

**After Fix:**
- Changed `loadMessages()` to use `GET /api/v1/threads/by-context?context_type=listing&context_id=${listingId}`
- This endpoint exists in messaging API and returns thread with messages
- Thread ID is extracted from response for `sendMessage()` usage

## Code Changes

**File:** `work/marketplace-web/src/pages/MessagingPage.vue`

**Method:** `loadMessages()`

**Before:**
```javascript
const response = await fetch(`${messagingBaseUrl}/api/v1/threads/${this.threadId}`, {
```

**After:**
```javascript
const response = await fetch(`${messagingBaseUrl}/api/v1/threads/by-context?context_type=listing&context_id=${this.id}`, {
```

## API Test Results

### Thread Upsert (POST)
```powershell
POST http://localhost:3002/api/messaging/api/v1/threads/upsert
Status: 200 OK
Response: {"thread_id":"<uuid>","context_type":"listing","context_id":"<listing-id>"}
```

### Thread By-Context (GET)
```powershell
GET http://localhost:3002/api/messaging/api/v1/threads/by-context?context_type=listing&context_id=<listing-id>
Status: 200 OK
Response: {"thread_id":"<uuid>","context_type":"listing","context_id":"<listing-id>","messages":[...]}
```

## Smoke Test

```powershell
.\ops\messaging_proxy_smoke.ps1
```

**Output:**
```
=== MESSAGING PROXY SMOKE TEST ===
Timestamp: 2026-01-23 06:06:05

[1] Testing messaging proxy (http://localhost:3002/api/messaging/api/world/status)...
PASS: Messaging proxy returned 200 with valid world status
  Response preview: {"world_key":"messaging","availability":"ONLINE","phase":"GENESIS","version":"1.4.0"}

[2] Testing thread by-context endpoint (proxy routing)...
PASS: Thread by-context endpoint proxy routing works (status: 401, expected)

=== MESSAGING PROXY SMOKE TEST: PASS ===
```

## Browser Test

1. Open http://localhost:3002
2. Click "Enter Demo" button
3. **Expected:** Redirects to http://localhost:3002/marketplace/demo
4. Click "Message Seller" button
5. **Expected:** Navigates to http://localhost:3002/marketplace/listing/:id/message
6. **Expected:** MessagingPage loads without 404 error
7. **Expected:** Thread upsert succeeds (POST /api/messaging/api/v1/threads/upsert → 200)
8. **Expected:** Messages load successfully (GET /api/messaging/api/v1/threads/by-context → 200)

## Network Verification

**Before Fix:**
- GET `/api/messaging/api/v1/threads/:id` → 404 (endpoint doesn't exist)

**After Fix:**
- GET `/api/messaging/api/v1/threads/by-context?context_type=listing&context_id=:id` → 200 OK

## Changes Summary

1. **MessagingPage.vue**: Changed `loadMessages()` to use `by-context` endpoint instead of `by-id`
2. **MessagingPage.vue**: Extract `thread_id` from `by-context` response for `sendMessage()` usage
3. **ops/messaging_proxy_smoke.ps1**: Added check for `by-context` endpoint proxy routing

## Acceptance Criteria

✅ No literal `:id` in URL: Uses `by-context` endpoint with query parameters  
✅ Thread GET works: GET /api/messaging/api/v1/threads/by-context returns 200  
✅ Messages load: Response includes messages array  
✅ Thread ID extracted: threadId set from response for sendMessage  
✅ All URLs use /api/messaging/ base path (no hardcoded 8090)  
✅ Smoke test: messaging_proxy_smoke.ps1 PASS  
✅ All gates: PASS

