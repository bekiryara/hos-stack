# WP-64: Create Listing Publish CTA + Strict Draft/Search UX

**Date:** 2026-01-24  
**Status:** ✅ PASS  
**Commit:** a38a3bd

---

## Summary

Improved Create Listing success panel with "Publish now" button for draft listings. After publishing, status updates to "published" and "Go to Search" button becomes available. Maintains strict draft/published UX: search shows only published listings by default.

**Scope:** Frontend-only changes. No new endpoints, no schema changes.

---

## Changes Made

### 1. CreateListingPage.vue Success Panel

**File:** `work/marketplace-web/src/pages/CreateListingPage.vue`

**Changes:**
- Added "Publish now" button for draft listings (replaces draft note)
- Implemented `handlePublish()` method that:
  - Calls existing `api.publishListing()` endpoint
  - Uses current tenant header strategy (no hardcoded tenant_id)
  - Updates local state: `success.status = 'published'`
  - Shows "Go to Search" button after successful publish
- Added `publishing` and `publishError` state tracking
- Conditional rendering:
  - Draft: Shows "Publish now" button
  - Published: Shows "Go to Search" button

**Code Snippet:**
```vue
<button v-if="success.status === 'draft'" @click="handlePublish" :disabled="publishing" class="action-button publish-button">
  {{ publishing ? 'Publishing...' : 'Publish now' }}
</button>
<button v-if="success.status === 'published' && success.category_id" @click="goToCategorySearch(success.category_id)" class="action-button">Go to Search</button>
```

### 2. ListingDetailPage.vue

**File:** `work/marketplace-web/src/pages/ListingDetailPage.vue`

**Status:** ✅ No changes needed
- Publish component (`PublishListingAction`) already exists and works
- Transaction mode badges (WP-63) remain intact

---

## API Endpoints Used

**Publish Endpoint:**
- `POST /api/marketplace/api/v1/listings/{id}/publish`
- Uses single-origin proxy (`/api/marketplace/*`)
- Headers: `X-Active-Tenant-Id` (from active tenant session)
- Optional: `Authorization` (if demo token exists)

**Create Endpoint:**
- `POST /api/marketplace/api/v1/listings`
- Creates listing with `status: 'draft'` (contract behavior)

**Search Endpoint:**
- `GET /api/marketplace/api/v1/listings?category_id={id}&status=published`
- Default filter: `status=published` (only published listings shown)

---

## User Flow

### Flow 1: Create → Publish → Search

1. **Create Listing:**
   - User fills form and submits
   - Listing created with `status: 'draft'`
   - Success panel shows:
     - Listing ID (with Copy button)
     - Status: draft
     - "View Listing" link
     - **"Publish now" button** (NEW)

2. **Publish Listing:**
   - User clicks "Publish now"
   - Button shows "Publishing..." (disabled)
   - API call: `POST /api/v1/listings/{id}/publish`
   - On success:
     - Local state updated: `status: 'published'`
     - "Publish now" button hidden
     - **"Go to Search" button appears** (NEW)

3. **Go to Search:**
   - User clicks "Go to Search"
   - Navigates to `/search/{category_id}`
   - Listing appears in search results (published listings only)

### Flow 2: Create → View → Publish (Detail Page)

1. **Create Listing:**
   - Listing created as draft
   - User clicks "View Listing"

2. **View Listing:**
   - Detail page shows listing with `status: 'draft'`
   - "Publish Listing" section visible
   - User can publish from detail page (existing functionality)

3. **Publish from Detail:**
   - `PublishListingAction` component handles publish
   - Status updates to `published`
   - Transaction mode badges remain visible (WP-63)

---

## Verification

### Manual Browser Test

**URLs:**
- Create: `http://localhost:3002/marketplace/listing/create`
- View: `http://localhost:3002/marketplace/listing/{id}`
- Search: `http://localhost:3002/marketplace/search/{category_id}`

**Steps:**
1. Create a new listing (category: Service, title: "WP-64 Test Listing")
2. Verify success panel shows:
   - Status: draft ✅
   - "Publish now" button visible ✅
   - "Go to Search" button NOT visible ✅
3. Click "Publish now"
4. Verify:
   - Button shows "Publishing..." (disabled) ✅
   - After success: Status updates to "published" ✅
   - "Publish now" button hidden ✅
   - "Go to Search" button appears ✅
5. Click "Go to Search"
6. Verify listing appears in search results ✅

### Network Requests

**Create Listing:**
```
POST /api/marketplace/api/v1/listings
Status: 201 Created
Response: { "id": "...", "status": "draft", ... }
```

**Publish Listing:**
```
POST /api/marketplace/api/v1/listings/{id}/publish
Status: 200 OK
Response: { "id": "...", "status": "published", ... }
```

**Search Listings:**
```
GET /api/marketplace/api/v1/listings?category_id=1&status=published
Status: 200 OK
Response: [{ "id": "...", "status": "published", ... }]
```

**All requests use single-origin proxy (`/api/marketplace/*`)** ✅

---

## Acceptance Criteria

✅ **Create Listing success panel shows "Publish now" for draft listings**
- Button visible when `success.status === 'draft'`
- Button disabled during publish operation
- Shows "Publishing..." text while loading

✅ **Publish updates local state to published**
- `success.status` updated to `'published'` after successful publish
- "Publish now" button hidden
- "Go to Search" button appears

✅ **"Go to Search" only shown for published listings**
- Conditional: `success.status === 'published' && success.category_id`
- Draft listings: "Go to Search" NOT shown

✅ **Single-origin proxy maintained**
- All API calls use `/api/marketplace/*`
- No direct `localhost:8080` calls

✅ **No hardcoded tenant IDs**
- Uses `api.getActiveTenantId()` or `formData.tenantId`
- Tenant ID from active session/memberships

✅ **ListingDetailPage publish component still works**
- `PublishListingAction` component functional
- Transaction mode badges (WP-63) intact

---

## Files Changed

1. `work/marketplace-web/src/pages/CreateListingPage.vue`
   - Added "Publish now" button for draft listings
   - Implemented `handlePublish()` method
   - Added `publishing` and `publishError` state
   - Updated success panel conditional rendering
   - Added publish button CSS styles

2. `work/marketplace-web/src/pages/ListingDetailPage.vue`
   - No changes (publish component already exists)

---

## Commands

```powershell
# Manual browser test
# 1. Open: http://localhost:3002/marketplace/listing/create
# 2. Create listing → Verify "Publish now" button
# 3. Click "Publish now" → Verify status updates
# 4. Click "Go to Search" → Verify listing in results

# Run smoke tests
.\ops\frontend_smoke.ps1
.\ops\prototype_flow_smoke.ps1
```

---

## Notes

- **Contract behavior maintained:** POST /api/v1/listings creates DRAFT
- **Search default:** Shows only PUBLISHED listings
- **No new endpoints:** Uses existing publish endpoint
- **Minimal diff:** Only CreateListingPage.vue modified
- **No tech debt:** Frontend-only changes, no schema changes

---

**Status:** ✅ PASS  
**Next Steps:** None (feature complete)

