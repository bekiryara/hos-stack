# CUSTOMER ORDER JOURNEY PROOF PACK (WP-70) - Proof Document

**Date:** 2026-01-25  
**Purpose:** Proof that authenticated customer can create orders and view them in Account Portal  
**Status:** ✅ COMPLETE

## Overview

This document provides proof that the authenticated customer order journey works end-to-end:
1. User can create an order from a sale listing using their login token
2. Created order appears in `/marketplace/account` "Siparişlerim" section
3. Order can be read via personal scope API endpoint (`/api/v1/orders?buyer_user_id=...`)
4. Messaging thread contract remains intact (if applicable)

## Preconditions

### Stack Verification

```powershell
.\ops\verify.ps1
```

**Expected:** All core services available (H-OS, Pazar, Messaging)

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

## Runbook

### 1. Order Contract Check (with Auth)

```powershell
cd D:\stack\ops
.\order_contract_check.ps1
```

**Expected Output (with auth):**
- Test 1: Order created successfully
- Test 1a: Authenticated buyer-order read assertion - PASS
  - Created order found in buyer orders
- Test 1b: Messaging thread exists for order
- Test 2: Idempotency replay - PASS
- Test 3: Unpublished listing rejection - PASS

**Expected Output (without auth):**
- Test 1: Order created successfully
- SKIP: Authenticated buyer-order read assertion (PRODUCT_TEST_AUTH not set)
- Test 1b: Messaging thread exists for order
- Test 2: Idempotency replay - PASS
- Test 3: Unpublished listing rejection - PASS

### 2. Account Portal Read Check

```powershell
.\account_portal_read_check.ps1
```

**Expected:** All 7 tests PASS (see WP-69 proof)

## Manual Smoke Test (UI)

### Steps

1. **Login:**
   - Navigate to: `http://localhost:3002/marketplace/login`
   - Email: `testuser@example.com`
   - Password: `Passw0rd!`
   - Click "Giriş Yap"
   - Should redirect to `/marketplace/account`

2. **Find Sale Listing:**
   - Navigate to marketplace home or search
   - Find a listing with `transaction_modes` containing `"sale"`
   - Click on the listing to open detail page

3. **Create Order:**
   - Click "Buy" button on listing detail page
   - Fill form (quantity defaults to 1)
   - Submit order
   - Should see success message with order details

4. **Verify in Account:**
   - Navigate to `/marketplace/account`
   - Scroll to "Siparişlerim" section
   - **Expected:** New order appears in the list
   - **Expected:** No error box visible
   - Order should show:
     - Order ID
     - Listing ID
     - Status
     - Quantity
     - Created timestamp

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

### Personal Scope Read

```powershell
# Get token from env
$token = $env:PRODUCT_TEST_AUTH

# Extract user ID from token (JWT sub claim)
# Or use: .\ops\ensure_product_test_auth.ps1 (shows user ID)

# Read buyer orders
$userId = "<user_id_from_token_sub>"
$url = "http://localhost:8080/api/v1/orders?buyer_user_id=$userId"
$headers = @{ "Authorization" = $token }
Invoke-RestMethod -Uri $url -Method Get -Headers $headers
```

**Expected Response:**
- Format: `{data: [...], meta: {...}}` or `[...]` (array)
- Created order ID should be in the list
- Order status: "placed"

## Contract Verification

### Order Creation

- **Endpoint:** `POST /api/v1/orders`
- **Headers:** `Authorization: Bearer <token>`, `Idempotency-Key: <key>`
- **Body:** `{listing_id: <uuid>, quantity: 1}`
- **Response:** `{id: <uuid>, status: "placed", ...}`

### Personal Scope Read

- **Endpoint:** `GET /api/v1/orders?buyer_user_id=<user_id>`
- **Headers:** `Authorization: Bearer <token>`
- **Response:** `{data: [...], meta: {...}}` or `[...]`
- **Assertion:** Created order ID must be in response

### Messaging Thread

- **Endpoint:** `GET /api/v1/threads/by-context?context_type=order&context_id=<order_id>`
- **Headers:** `messaging-api-key: dev-messaging-key`
- **Response:** `{thread_id: <uuid>, context_type: "order", ...}`
- **Contract:** Thread should exist for created order

## Files Changed

1. `ops/order_contract_check.ps1` (MODIFIED)
   - Added optional auth token handling
   - Added JWT sub extraction helper
   - Added personal read assertion (Test 1a)
   - Authorization header added to order create/replay requests

## Acceptance Criteria

✅ Token YOK: order_contract_check PASS (auth segment SKIP)  
✅ Token VAR: order_contract_check PASS (auth segment PASS)  
✅ Created orderId found in buyer orders (assertion)  
✅ Manual UI smoke test: Order appears in "Siparişlerim"  
✅ Messaging thread contract intact  
✅ No backend changes required

## Notes

- Auth segment is optional: Script works with or without `PRODUCT_TEST_AUTH`
- Personal read assertion only runs when auth token is set
- All existing tests (idempotency, draft listing, messaging) remain unchanged
- Backend untouched: Only ops script modified

