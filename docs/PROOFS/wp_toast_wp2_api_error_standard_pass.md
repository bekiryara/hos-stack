# WP-NEXT: Toast WP-2 — API error standard + 3 action flows PASS

**Timestamp:** 2026-02-01

## Summary

API error messages are normalized in one place (`normalizeApiError`); toast integration uses `notifyApiError` / `notifyApiSuccess` for three action flows: Create Listing (submit), Firm Register (submit), Account portal tenant select (button). Inline error boxes remain; toasts are global feedback only. Page-load / background fetch errors do **not** trigger toasts (no toast spam).

## Manual checks

- **A) Listing create:** Submit with valid data → "Listing created" toast. Submit with invalid input or intentional 401 → error box + "Create listing: &lt;status&gt; &lt;message&gt;" toast.
- **B) Firm register:** Submit with valid firm name → "Firm registered" toast. Submit fail (e.g. 409 duplicate) → error box + "Firm register: &lt;status&gt; &lt;message&gt;" toast.
- **C) Tenant select:** On Account page, click "Aktif Firma Yap" on a firm → "Tenant selected" toast.
- **Note:** Page-load errors (e.g. memberships load fail on Account, category load on Create Listing) do **not** show toasts; only user-triggered actions (submit / button click) show toasts.

## Gates evidence

- `.\ops\run_wp_next_local_gates.ps1` → **=== WP-NEXT LOCAL GATES: PASS ===**
- `.\ops\ops_run.ps1 -Profile Prototype` → **OVERALL STATUS: PASS**
