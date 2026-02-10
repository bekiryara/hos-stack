# CategoryPickerStepper UI Testing - Verification Report

**Date:** February 10, 2026  
**Task:** Verify non-leaf category selection (especially Televizyon) in Create Listing flow  
**Status:** ✅ Backend verified, Manual UI testing required

---

## 🔍 Backend Verification Results

### 1. API Categories Endpoint (`/api/v1/categories`)

**Endpoint:** `http://localhost:8080/api/v1/categories`  
**Status:** ✅ Working

**Key Findings:**
- The API correctly returns `selectable_for_create` flag for all categories
- Trendyol product categories (prefix `service-product-ty-c*`) are marked selectable even when they have children

**Test Categories Verified:**

| Category | Slug | ID | Has Children | selectable_for_create |
|----------|------|----|--------------|-----------------------|
| **Televizyon** | service-product-ty-c104156 | 1108 | ✅ Yes (1 child) | ✅ **True** |
| **Kitap** | service-product-ty-c91 | 2149 | ✅ Yes (10 children) | ✅ **True** |
| **Duvar Saati** | service-product-ty-c35 | 2241 | ❌ No (leaf) | ✅ True |

### 2. Filter Schema Endpoints

All test categories return proper filter schemas with attributes:

#### Televizyon (ID: 1108)
- **Total filters:** 15
- **Has `product_brand` (Marka):** ✅ Yes (67 brand options)
- **`product_ty_attr_*` fields:** ✅ 12 fields including:
  - `product_ty_attr_23`: Ekran Boyutu
  - `product_ty_attr_133`: Görüntüleme Teknolojisi
  - `product_ty_attr_698`: Ekran Yenileme Hızı
  - `product_ty_attr_149`: Görüntü Kalitesi
  - `product_ty_attr_28`: İşletim Sistemi
  - `product_ty_attr_362`: Smart TV
  - `product_ty_attr_648`: Model Yılı
  - `product_ty_attr_365`: Wi-Fi Özelliği
  - `product_ty_attr_364`: Dahili Uydu Alıcı
  - `product_ty_attr_358`: Çözünürlük (Piksel)
  - `product_ty_attr_361`: HDR
  - `product_ty_attr_348`: Renk

#### Kitap (ID: 2149)
- **Total filters:** 16
- **Has `product_brand` (Marka):** ✅ Yes
- **`product_ty_attr_*` fields:** ✅ 13 fields

#### Duvar Saati (ID: 2241)
- **Total filters:** 8
- **Has `product_brand` (Marka):** ✅ Yes
- **`product_ty_attr_*` fields:** ✅ 5 fields

---

## 🖥️ Frontend Code Review

### CategoryPickerStepper.vue Changes ✅

**Key Implementation (Lines 205-211):**

```javascript
isSelectableForCreate(cat) {
  if (!cat) return false;
  // Prefer server-provided semantics (prevents leaf-only drift across clients).
  if (typeof cat.selectable_for_create === 'boolean') return cat.selectable_for_create;
  // Fallback: legacy behavior
  return this.isLeaf(cat);
}
```

**Selection Logic (Lines 221-244):**
- ✅ Non-leaf categories with `selectable_for_create: true` can be selected
- ✅ Selection DOES NOT auto-drill-down for create mode (Line 229-231)
- ✅ Shows "Seçilebilir" badge in search results (Line 32)
- ✅ Shows checkmark icon in category buttons (Line 85)

### Backend API Logic ✅

**File:** `work/pazar/routes/api/02_catalog.php` (Lines 30-46)

```php
// Rationale: In Trendyol product taxonomy, some categories can be bindable even if they have children.
// For now, allow selecting non-leaf ONLY for Trendyol-derived product categories (service-product-ty-c<ID>).
$isTrendyolProductCategory = str_starts_with($slug, 'service-product-ty-c');
// Leaf categories are always selectable; non-leaf only if Trendyol product category.
$c['selectable_for_create'] = !$hasChildren || $isTrendyolProductCategory;
```

### CreateListingForm Integration ✅

**File:** `work/marketplace-web/src/components/listing/create/CreateListingForm.vue`

- ✅ Uses `CategoryPickerStepper` with `mode="create"` (Line 38)
- ✅ Renders attributes from `filterSchema` (Lines 96-112)
- ✅ Filters attributes by `applies_to_transaction_modes` (Line 168)
- ✅ Shows field count and labels via `FilterField` component (Line 106-110)

---

## 📋 Manual UI Testing Checklist

### Prerequisites
- ✅ Backend API running: `http://localhost:8080`
- ✅ Frontend running: `http://localhost:3002/marketplace`
- ⚠️ **Requires login + active firm** (route has `requiresAuth: true, requiresFirm: true`)

### Test Steps

#### Step 1: Navigate to Create Listing Page
1. Open browser: `http://localhost:3002/marketplace`
2. Login if not already logged in
3. Ensure you have an active firm selected (via `/account` page)
4. Navigate to: **`http://localhost:3002/marketplace/listing/create`**
   - Or use UI navigation if available

#### Step 2: Test Televizyon (Non-leaf Category)
1. **In the category picker search box, type:** `Televizyon`
2. **Observe search results:**
   - ✅ Should show "Televizyon" with "Seçilebilir" badge
   - ✅ Should NOT show "Alt kategori seç" warning
3. **Click on the Televizyon result**
4. **Verify:**
   - ✅ The "Seçili" display shows: "Seçili: [path to Televizyon]"
   - ✅ Category picker DOES NOT auto-navigate to children
   - ✅ Selection "sticks" (doesn't immediately clear)
5. **Scroll down to "Attributes" section**
6. **Verify fields appear:**
   - ✅ "Marka" (product_brand) dropdown visible
   - ✅ Multiple "Ekran Boyutu", "Görüntüleme Teknolojisi", etc. fields visible
   - ✅ Count roughly ~12-15 attribute fields total

**Alternative search:** Try searching for `service-product-ty-c104156` (slug) - should find same category

#### Step 3: Test Kitap (Another Non-leaf Category)
1. **Clear the previous selection** (click "Temizle" button)
2. **Search for:** `Kitap` or `service-product-ty-c91`
3. **Click to select it**
4. **Verify:**
   - ✅ Selection sticks (not forced into child selection)
   - ✅ "Seçili" display shows Kitap path
   - ✅ Attributes section renders with ~16 fields
   - ✅ "Marka" field present

#### Step 4: Test Duvar Saati (Leaf Category - Control)
1. **Clear selection**
2. **Search for:** `Duvar Saati` or `service-product-ty-c35`
3. **Click to select**
4. **Verify:**
   - ✅ Selection works (leaf categories should always work)
   - ✅ Attributes section shows ~8 fields
   - ✅ "Marka" field present

#### Step 5: Test Non-Selectable Non-leaf Category (Negative Test)
1. **Clear selection**
2. **Navigate via breadcrumb to a non-Trendyol parent category** (e.g., "Vasıta" or "Konut")
3. **Try to click a non-leaf category that is NOT a `service-product-ty-c*` category**
4. **Expected behavior:**
   - ❌ Should NOT show "Seçilebilir" badge
   - ⚠️ In create mode, clicking should navigate to children (NOT select it)
   - ⚠️ "Alt kategori seç" hint should appear in search results

---

## 🎯 What to Look For (Success Criteria)

### ✅ Must Work:
1. **Televizyon** can be selected in Create Listing mode
2. Selection **persists** without forcing child navigation
3. **Attributes section renders** after selection
4. **"Marka" (product_brand) field** is visible
5. **12+ `product_ty_attr_*` fields** are visible (Ekran Boyutu, etc.)
6. **Other non-leaf Trendyol categories** (Kitap, etc.) also selectable

### ❌ Must NOT Happen:
1. Selecting Televizyon does NOT immediately navigate to its child
2. Selection does NOT get cleared/reset automatically
3. Attributes section does NOT stay empty
4. No console errors related to `selectable_for_create`

---

## 🔧 Environment Info

- **Frontend URL:** http://localhost:3002/marketplace
- **Backend API:** http://localhost:8080
- **Docker Container:** stack-hos-web-1 (port 3002 → 80)
- **Router Mode:** HTML5 History mode (NO hash routing)
- **Auth Required:** Yes (login + firm membership)

---

## 🚨 Known Limitations

1. **Browser automation unavailable** - Manual testing required
2. **Auth required** - Must have valid session + firm membership
3. **Cannot create actual listings** - Focus is on category selection + attribute rendering
4. **Tenant ID** - If no firm, page will show "Aktif firma bulunamadı" warning

---

## 📸 Screenshot Checklist

If performing manual testing, capture:
1. ✅ Televizyon search results showing "Seçilebilir" badge
2. ✅ Televizyon selected with "Seçili: [path]" display
3. ✅ Attributes section with Marka and ty_attr fields visible
4. ✅ Kitap selected + attributes
5. ✅ Duvar Saati selected + attributes (control)
6. ❌ Non-Trendyol category showing "Alt kategori seç" hint (negative test)

---

## 🎉 Conclusion

**Backend Status:** ✅ VERIFIED  
**Frontend Code:** ✅ VERIFIED  
**UI Testing:** ⏳ REQUIRES MANUAL VERIFICATION

All backend logic and frontend code changes are in place and correct. The `selectable_for_create` flag is properly set for Trendyol categories, and the CategoryPickerStepper component correctly respects this flag. Manual UI testing is needed to visually confirm the behavior works as expected in the browser.

---

**Next Steps for Human Tester:**
1. Follow the manual testing checklist above
2. Verify Televizyon and other non-leaf categories are selectable
3. Confirm attribute fields render correctly
4. Report any UI issues or unexpected behavior
