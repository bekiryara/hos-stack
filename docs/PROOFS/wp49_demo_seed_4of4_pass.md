# WP-49: Demo Seed 4/4 Determinism (Fix Bando Presto 422)

**Date:** 2026-01-24  
**Status:** PASS

## Problem

demo_seed_root_listings.ps1 was failing for "Bando Presto (4 kişi)" with HTTP 422:
- Error: category_id, 	itle, 	ransaction_modes fields required
- Root cause: Invoke-RestMethod was not sending the JSON body correctly to Laravel

## Solution

Changed from Invoke-RestMethod to Invoke-WebRequest with explicit UTF-8 encoding:
- Use ConvertTo-Json -Depth 3 -Compress for JSON serialization
- Convert JSON string to UTF-8 bytes: [System.Text.Encoding]::UTF8.GetBytes({
    "category_id":  3,
    "title":  "Bando Presto (4 kişi)",
    "description":  "WP-48 showcase listing",
    "attributes":  {
                       "capacity_max":  100
                   },
    "transaction_modes":  [
                              "reservation",
                              "rental"
                          ]
})
- Use Invoke-WebRequest with -ContentType "application/json; charset=utf-8"
- Parse response: $webRequest.Content | ConvertFrom-Json

## Verification

### Commands Run

```powershell
.\ops\demo_seed_root_listings.ps1
.\ops\catalog_contract_check.ps1
.\ops\listing_contract_check.ps1
.\ops\frontend_smoke.ps1
```

### Results

**demo_seed_root_listings.ps1:**
- Bando Presto (4 kişi): CREATED (id: d1044bf2-94bc-44c0-a5a7-51c20038db80)
- Ruyam Tekne Kiralık: CREATED
- Mercedes (Kiralık): CREATED
- Adana Kebap: EXISTS
- **Result: PASS (4/4 listings)**

**Idempotency Test:**
- Re-run: All listings show EXISTS (no duplicates)
- **Result: PASS**

**Gates:**
- catalog_contract_check: PASS (Exit: 0)
- listing_contract_check: PASS (Exit: 0)
- frontend_smoke: PASS (Exit: 0)

## Files Changed

- ops/demo_seed_root_listings.ps1:
  - Changed Invoke-RestMethod to Invoke-WebRequest for listing creation
  - Added explicit UTF-8 encoding for JSON body
  - Added -Compress flag to ConvertTo-Json

## Summary

WP-49 successfully fixed the 422 error for Bando Presto by using Invoke-WebRequest with explicit UTF-8 encoding instead of Invoke-RestMethod. All 4 showcase listings now seed successfully, and the script is idempotent.

