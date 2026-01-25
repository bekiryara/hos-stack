# CUSTOMER MESSAGING JOURNEY PROOF PACK (WP-71) - Proof Document

**Date:** 2026-01-25  
**Purpose:** Proof that authenticated customer messaging journey works end-to-end (upsert, ping, send, verify)  
**Status:** ✅ COMPLETE

## Overview

This document provides proof that the authenticated customer messaging journey works end-to-end:
1. User can upsert a thread for a listing context
2. By-context read returns thread_id immediately (PING verification)
3. User can send a message to the thread
4. Sent message appears in by-context read response

## Preconditions

### Stack Verification

```powershell
.\ops\verify.ps1
```

**Expected:** All core services available (H-OS, Pazar, Messaging, Hos-web proxy)

### Auth Token Setup

**Option 1: From UI (DevTools Console)**
```javascript
// In browser DevTools Console (after login)
localStorage.getItem('demo_auth_token')
// Copy the token value
```

**Option 2: Via ensure_product_test_auth.ps1**
```powershell
cd D:\stack\ops
.\ensure_product_test_auth.ps1
```

**Set Environment Variable:**
```powershell
$env:PRODUCT_TEST_AUTH = "Bearer <PASTE_TOKEN>"
```

**Optional: Set Test Listing ID**
```powershell
$env:TEST_LISTING_ID = "<listing_uuid>"
# If not set, script will find first published listing from API
```

## Runbook

### 1. Messaging Journey Check

```powershell
cd D:\stack\ops
.\messaging_journey_check.ps1
```

**Expected Output (with auth):**
- Auth enabled: User ID from token: <user_id>
- Found published listing: <listing_id>
- [1] PASS: Thread upserted successfully
  - Thread ID: <thread_id>
  - Context: listing / <listing_id>
- [2] PASS: By-context read successful (PING verified)
  - Thread ID: <thread_id>
  - Messages count: <count>
- [3] PASS: Message sent successfully
  - Message ID: <message_id>
  - Body: wp-71 ping test <timestamp>
- [4] PASS: Sent message found in by-context response
  - Message ID: <message_id>
  - Total messages: <count>
- === MESSAGING JOURNEY CHECK: PASS ===

**Expected Output (without auth):**
- SKIP: Authenticated messaging checks (PRODUCT_TEST_AUTH not set)
- === MESSAGING JOURNEY CHECK: PASS ===

## Manual Smoke Test (UI)

### Steps

1. **Login:**
   - Navigate to: `http://localhost:3002/marketplace/login`
   - Email: `testuser@example.com`
   - Password: `Passw0rd!`
   - Click "Giriş Yap"
   - Should redirect to `/marketplace/account`

2. **Open Listing Detail:**
   - Navigate to marketplace home or search
   - Click on any published listing to open detail page

3. **Open Messaging:**
   - Click "Message Seller" or similar messaging button
   - Should navigate to messaging page for that listing

4. **Verify PING (Immediate Load):**
   - **Expected:** Page opens immediately without errors
   - **Expected:** Thread loads automatically (PING feeling)
   - **Expected:** No "Loading..." spinner for extended time
   - **Expected:** Thread ID visible in DevTools Network tab

5. **Send Message:**
   - Type a test message (e.g., "wp-71 test message")
   - Click "Send" or submit
   - **Expected:** Message appears in the conversation list immediately
   - **Expected:** No error messages

6. **Verify Message Persistence:**
   - Refresh the page
   - **Expected:** Sent message still visible in conversation
   - **Expected:** Message order correct (newest at bottom or top)

### UI Rebuild (if needed)

If UI code changed:
```powershell
cd D:\stack
docker compose build hos-web
docker compose up -d --force-recreate hos-web
```

**Verification:**
- DevTools: Disable cache + Ctrl+Shift+R (hard reload)
- Check `/marketplace/assets/index-*.js` hash changed

## API Verification

### Thread Upsert

```powershell
# Get token from env
$token = $env:PRODUCT_TEST_AUTH
$listingId = "<listing_uuid>"
$userId = "<user_id_from_token_sub>"

# Upsert thread
$url = "http://localhost:3002/api/messaging/api/v1/threads/upsert"
$headers = @{
    "Authorization" = $token
    "messaging-api-key" = "dev-messaging-key"
    "Content-Type" = "application/json"
}
$body = @{
    context_type = "listing"
    context_id = $listingId
    participants = @(
        @{ type = "user"; id = $userId }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers
```

**Expected Response:**
- `{thread_id: <uuid>, context_type: "listing", context_id: <listing_id>, ...}`

### By-Context Read (PING)

```powershell
# Read thread by context
$url = "http://localhost:3002/api/messaging/api/v1/threads/by-context?context_type=listing&context_id=$listingId"
$headers = @{
    "Authorization" = $token
    "messaging-api-key" = "dev-messaging-key"
}

Invoke-RestMethod -Uri $url -Method Get -Headers $headers
```

**Expected Response:**
- `{thread_id: <uuid>, context_type: "listing", context_id: <listing_id>, messages: [...], ...}`
- **PING Verification:** Response returns immediately (200 OK) with thread_id

### Send Message

```powershell
# Send message
$threadId = "<thread_id>"
$url = "http://localhost:3002/api/messaging/api/v1/threads/$threadId/messages"
$body = @{
    sender_type = "user"
    sender_id = $userId
    body = "wp-71 test message"
} | ConvertTo-Json

Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers
```

**Expected Response:**
- `{message_id: <uuid>, body: "wp-71 test message", ...}`

### Verify Message in By-Context

```powershell
# Read by-context again
$url = "http://localhost:3002/api/messaging/api/v1/threads/by-context?context_type=listing&context_id=$listingId"
$response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

# Check if message is in response
$response.messages | Where-Object { $_.body -eq "wp-71 test message" }
```

**Expected:** Message found in messages array

## Contract Verification

### Thread Upsert

- **Endpoint:** `POST /api/messaging/api/v1/threads/upsert`
- **Headers:** `Authorization: Bearer <token>`, `messaging-api-key: dev-messaging-key`
- **Body:** `{context_type: "listing", context_id: <uuid>, participants: [{type: "user", id: <user_id>}]}`
- **Response:** `{thread_id: <uuid>, context_type: "listing", ...}`

### By-Context Read (PING)

- **Endpoint:** `GET /api/messaging/api/v1/threads/by-context?context_type=listing&context_id=<uuid>`
- **Headers:** `Authorization: Bearer <token>`, `messaging-api-key: dev-messaging-key`
- **Response:** `{thread_id: <uuid>, messages: [...], ...}`
- **PING Verification:** Response returns immediately (200 OK) with thread_id

### Send Message

- **Endpoint:** `POST /api/messaging/api/v1/threads/<thread_id>/messages`
- **Headers:** `Authorization: Bearer <token>`, `messaging-api-key: dev-messaging-key`
- **Body:** `{sender_type: "user", sender_id: <user_id>, body: "<message>"}`
- **Response:** `{message_id: <uuid>, body: "<message>", ...}`

### Message Verification

- **Endpoint:** `GET /api/messaging/api/v1/threads/by-context?context_type=listing&context_id=<uuid>`
- **Assertion:** Sent message body must appear in `messages` array

## Files Changed

1. `ops/messaging_journey_check.ps1` (NEW)
   - Optional auth token handling
   - JWT sub extraction helper
   - Listing ID discovery (env or API)
   - 4 tests: upsert, by-context (ping), send message, verify message
   - Hos-web proxy usage (`/api/messaging`)

## Acceptance Criteria

✅ Token YOK: messaging_journey_check PASS (auth segment SKIP)  
✅ Token VAR: All 4 tests PASS  
✅ Thread upsert works  
✅ By-context read returns thread_id (PING verified)  
✅ Message send works  
✅ Sent message appears in by-context response  
✅ Manual UI smoke: Messaging page opens immediately (PING feeling)  
✅ No backend changes required

## Notes

- Auth segment is optional: Script works with or without `PRODUCT_TEST_AUTH`
- Hos-web proxy is used (`/api/messaging`) for same-origin policy
- Listing ID can be set via `TEST_LISTING_ID` env or auto-discovered from API
- PING verification: By-context read returns immediately with thread_id (no delay)
- All messaging operations use authenticated endpoints (Authorization header)

