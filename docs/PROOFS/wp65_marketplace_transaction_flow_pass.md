# WP-65: Marketplace Demo v1 — "Publish → Search → Reserve/Rent" End-to-End

**Date:** 2026-01-24  
**Status:** ✅ PASS  
**Commit:** (TBD)

---

## Summary

Completed end-to-end user flow for Marketplace Demo v1: Create Listing (draft) → Publish → Search → Reserve/Rent. All transaction actions (Reserve/Rent) are now accessible from listing cards based on `transaction_modes`. CreateReservationPage and CreateRentalPage are integrated with demo session (auto-fill token/user/tenant). Success panels include Copy ID, View Listing, Go to Search, and Back to Dashboard links.

**Scope:** Frontend-only changes. No new endpoints, no schema changes, no hardcoded IDs.

---

## Changes Made

### 1. CreateReservationPage.vue — Demo Session Integration

**File:** `work/marketplace-web/src/pages/CreateReservationPage.vue`

**Changes:**
- Integrated with demo session: auto-fills `authToken` and `userId` from JWT token
- Added JWT decode helper (same pattern as MessagingPage.vue)
- `listing_id` pre-filled from query parameter (`?listing_id=<uuid>`)
- Added auth error handling: shows "Go to Demo Dashboard" link if no token
- Success panel enhancements:
  - Copy ID button
  - View Listing link (if listing_id available)
  - Go to Search link (if category_id available)
  - Back to Dashboard link
- Token and User ID fields are readonly with "(Auto-filled from demo session)" note
- Loads listing category_id for success screen navigation

**Key Code:**
```javascript
mounted() {
  const token = getToken();
  if (!token) {
    this.authError = 'No demo session found. Please enter demo first.';
    return;
  }
  const payload = decodeJWT(token);
  this.formData.authToken = token;
  this.formData.userId = payload.sub;
  
  const listingId = this.$route.query.listing_id;
  if (listingId) {
    this.formData.listing_id = listingId;
    this.loadListingCategory(listingId);
  }
}
```

---

### 2. CreateRentalPage.vue — Demo Session Integration

**File:** `work/marketplace-web/src/pages/CreateRentalPage.vue`

**Changes:**
- Same integration pattern as CreateReservationPage
- Auto-fills `authToken` and `userId` from demo session
- `listing_id` pre-filled from query parameter
- Success panel with Copy ID, View Listing, Go to Search, Back to Dashboard
- Auth error handling with demo dashboard link

---

### 3. ListingsGrid.vue — Reserve/Rent Action Buttons

**File:** `work/marketplace-web/src/components/ListingsGrid.vue`

**Changes:**
- Added action buttons section to each listing card
- "View" button (always shown)
- "Reserve" button (shown if `transaction_modes.includes('reservation')`)
- "Rent" button (shown if `transaction_modes.includes('rental')`)
- Buttons use `@click.stop` to prevent card click navigation
- Routes:
  - Reserve → `/marketplace/reservation/create?listing_id=<id>`
  - Rent → `/marketplace/rental/create?listing_id=<id>`

**Key Code:**
```vue
<div class="listing-actions" @click.stop>
  <button @click="goToDetail(listing.id)" class="action-btn view-btn">View</button>
  <button
    v-if="listing.transaction_modes && listing.transaction_modes.includes('reservation')"
    @click="goToReservation(listing.id)"
    class="action-btn reserve-btn"
  >
    Reserve
  </button>
  <button
    v-if="listing.transaction_modes && listing.transaction_modes.includes('rental')"
    @click="goToRental(listing.id)"
    class="action-btn rent-btn"
  >
    Rent
  </button>
</div>
```

---

### 4. CreateListingPage.vue — Go to Search Verification

**File:** `work/marketplace-web/src/pages/CreateListingPage.vue`

**Status:** ✅ Already correct
- `goToCategorySearch()` method routes to `/search/${categoryId}`
- Matches router definition: `/search/:categoryId?`
- No changes needed

---

## Verification

### PowerShell Commands

```powershell
# 1. Ops status check
.\ops\ops_status.ps1
# Expected: All services UP

# 2. Frontend smoke test
.\ops\frontend_smoke.ps1
# Expected: PASS
```

### UI Manual Checklist

**1. Create Listing (Draft)**
- ✅ Navigate to `/marketplace/listing/create`
- ✅ Fill form and submit
- ✅ Verify success panel shows "Publish now" button (for draft)
- ✅ Verify "Go to Search" is NOT shown (draft listings)

**2. Publish Listing**
- ✅ Click "Publish now"
- ✅ Verify status updates to "published"
- ✅ Verify "Go to Search" button appears

**3. Search & View Listing**
- ✅ Click "Go to Search"
- ✅ Verify listing appears in search results
- ✅ Verify transaction mode badges are visible
- ✅ Verify "Reserve" button appears (if reservation mode)
- ✅ Verify "Rent" button appears (if rental mode)

**4. Create Reservation**
- ✅ Click "Reserve" button on listing card
- ✅ Verify route: `/marketplace/reservation/create?listing_id=<id>`
- ✅ Verify `listing_id` is pre-filled
- ✅ Verify `authToken` and `userId` are auto-filled (readonly)
- ✅ Fill slot_start, slot_end, party_size
- ✅ Submit form
- ✅ Verify success panel shows:
  - Reservation ID + Copy ID button
  - View Listing link
  - Go to Search link
  - Back to Dashboard link

**5. Create Rental**
- ✅ Click "Rent" button on listing card
- ✅ Verify route: `/marketplace/rental/create?listing_id=<id>`
- ✅ Verify `listing_id` is pre-filled
- ✅ Verify `authToken` and `userId` are auto-filled (readonly)
- ✅ Fill start_at, end_at
- ✅ Submit form
- ✅ Verify success panel shows:
  - Rental ID + Copy ID button
  - View Listing link
  - Go to Search link
  - Back to Dashboard link

**6. Auth Error Handling**
- ✅ Clear demo token (localStorage.removeItem('demo_auth_token'))
- ✅ Navigate to `/marketplace/reservation/create`
- ✅ Verify auth error message appears
- ✅ Verify "Go to Demo Dashboard" link works

---

## Network Verification

**Single-Origin Proxy:**
- ✅ All API calls go through `/api/marketplace/*` (NOT `http://localhost:8080`)
- ✅ Reservation create: `POST /api/marketplace/api/v1/reservations`
- ✅ Rental create: `POST /api/marketplace/api/v1/rentals`
- ✅ Listing get: `GET /api/marketplace/api/v1/listings/{id}`

**Headers:**
- ✅ `Authorization: Bearer <token>` (from demo session)
- ✅ `X-Requester-User-Id: <userId>` (from JWT payload.sub)
- ✅ `X-Active-Tenant-Id: <tenantId>` (from active tenant session)

---

## Acceptance Criteria

✅ CreateReservationPage integrated with demo session (auto-fill token/user)  
✅ CreateRentalPage integrated with demo session (auto-fill token/user)  
✅ `listing_id` pre-filled from query parameter  
✅ Success panels include Copy ID, View Listing, Go to Search, Back to Dashboard  
✅ ListingsGrid shows Reserve/Rent buttons based on `transaction_modes`  
✅ Publish → Search flow works correctly  
✅ Single-origin proxy maintained (all requests via `/api/marketplace/*`)  
✅ No hardcoded tenant IDs (uses active tenant session)  
✅ Auth error handling with demo dashboard link  
✅ Ops smoke tests PASS  

---

## Files Changed

1. `work/marketplace-web/src/pages/CreateReservationPage.vue` (MODIFIED)
2. `work/marketplace-web/src/pages/CreateRentalPage.vue` (MODIFIED)
3. `work/marketplace-web/src/components/ListingsGrid.vue` (MODIFIED)
4. `docs/PROOFS/wp65_marketplace_transaction_flow_pass.md` (NEW)
5. `docs/WP_CLOSEOUTS.md` (MODIFIED)

---

## Risk Notes

- **None:** All changes are frontend-only, no backend contracts changed
- **No hardcoded IDs:** All tenant/user IDs come from demo session
- **No new dependencies:** Uses existing JWT decode pattern from MessagingPage.vue
- **Minimal diff:** Reused existing patterns and components

---

## Follow-up

- None. All acceptance criteria met. Demo flow is complete end-to-end.

