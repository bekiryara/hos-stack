# WP-NEXT: Account tabs + lazy-load PASS

**Timestamp:** 2026-01-31  
**Summary:** /account tabs (Orders / Rentals / Reservations) + panels lazy-load; Create success "View My …" / "Go to Account" deep-link to correct tab. Backend unchanged.

## Changes

- **AccountPortalPage.vue:** allowedTabs, activeTab from route.query.tab (default 'orders'); tab UI (3 buttons); panels with :active, v-show; setTab() → router.replace query; refreshAll() only refreshes active panel.
- **MyOrdersPanel / MyRentalsPanel / MyReservationsPanel:** prop `active` (default false); `loadedOnce`; watch `active` (immediate) → load when first active and set loadedOnce; load() no-op when !active.
- **CreateOrderPage.vue:** "View My Orders" → /account?tab=orders.
- **CreateRentalPage.vue:** "Go to Account" → /account?tab=rentals.
- **CreateReservationPage.vue:** "Go to Account" → /account?tab=reservations.

## Manual steps (kanıt)

1. /account?tab=orders aç → sadece Orders panel load olur (network’te tek getMyOrders).
2. Tabs ile Rentals/Reservations’a geç → ilk geçişte ilgili panel load olur; tekrar aynı tab’a dönünce yeniden fetch yok (loadedOnce).
3. Create Order/Rental/Reservation success → "View My Orders" / "Go to Account" tıkla → /account ilgili tab açılır.

## Gates evidence

```text
.\ops\run_wp_next_local_gates.ps1   => === WP-NEXT LOCAL GATES: PASS ===
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS
```

**Commit:** `b81447b` — WP-NEXT: Account tabs + lazy-load records — PASS
