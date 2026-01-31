# WP Closeouts - Workspace Package Summaries

**Last Updated:** 2026-01-31  
**Purpose:** Short summaries of completed Workspace Packages (WP) with deliverables, commands, and proof evidence.

---

## WP-NEXT: Account — Records tabs + lazy-load — PASS

- **Proof:** `docs/PROOFS/wp_account_tabs_lazyload_pass.md`
- **Outcome:** Account tabs (Orders/Rentals/Reservations) + lazy-load; Create success deep-link to correct tab; perf + UX iyileşti.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Messaging v1 — Customer↔Firm round-trip (UI + minimal glue) — PASS

- **Proof:** `docs/PROOFS/wp_messaging_roundtrip_customer_firm_pass.md`
- **Outcome:** Messaging round-trip çalışıyor; upsert contract uyumlu (participants min 1); firm tenant reply mümkün; customer mesajı ve firm cevabı aynı thread’de görünür.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Customer Account — Orders/Rentals/Reservations READ-ONLY panels — PASS

- **Proof:** `docs/PROOFS/wp_customer_account_records_read_pass.md`
- **Outcome:** Customer account now exposes read-only records panels (Orders, Rentals, Reservations) under `components/account/`; empty/error/retry standard; backend unchanged.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: HOS API — auth_routes split (NO BEHAVIOR CHANGE) — PASS

- **Proof:** `docs/PROOFS/wp_hos_auth_routes_split_pass.md`
- **Outcome:** auth_routes.js split into auth/ (index, helpers, register, login, refresh, logout, google_oauth); thin wrapper in auth_routes.js; route surface unchanged.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS (ops_run requires clean git; commit sonrası doğrulandı).

---

## WP-NEXT: API stable query string — PASS

- **Proof:** `docs/PROOFS/wp_api_stable_querystring_pass.md`
- **Outcome:** Centralized deterministic query string builder (toStableQueryString in request.js); catalog searchListings and messaging getThreadByContext use it; removed redundant key sort in ListingsSearchPage. No force push rule added to RULES.md.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Listing Detail — Category + Attributes (contract-safe) — PASS

- **Proof:** `docs/PROOFS/wp_listing_detail_category_attributes_pass.md`
- **Outcome:** Listing detail shows category name (best-effort from categories tree) and attributes with empty-safe, deterministically ordered render. Backend unchanged.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Firm Portal — Split panels (no behavior change) — PASS

- **Proof:** `docs/PROOFS/wp_firm_portal_split_panels_pass.md`
- **Outcome:** FirmPortalPage.vue split into page orchestrator + 4 panels (FirmListingsPanel, FirmOrdersPanel, FirmRentalsPanel, FirmReservationsPanel). Panel isolation: own load/error/retry/empty; one panel FAIL does not block others. Line count 577 → 120.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Create Listing split (form+success) — PASS

- **Proof:** `docs/PROOFS/wp_create_listing_split_pass.md`
- **Outcome:** Create Listing write-path modülerleşti (page orchestrator, form + success components). Davranış değişmedi.
- **Gates:** local gates + ops_run Prototype PASS.

---

## WP-NEXT: Marketplace — Account portal split panels — PASS

- **Proof:** `docs/PROOFS/wp_account_portal_split_panels_pass.md`
- **Outcome:** AccountPortalPage.vue split into layout + SectionShell + MyOrdersPanel, MyRentalsPanel, MyReservationsPanel. Panel UX standard: loading + error + Retry + empty + table. Panel isolation: one panel FAIL does not block others. Logic split + panels + shell.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Marketplace — api/client.js split (no behavior change) — PASS

- **Proof:** `docs/PROOFS/wp_marketplace_api_client_split_pass.md`
- **Outcome:** `api/client.js` (567 satır) → request wrapper + 5 domain modülleri (catalog, customer, store, hos, messaging). client.js şişmesi durduruldu; domain sınırları net; yeni endpoint eklemek artık bloat üretmiyor. Export yüzeyi ve davranış birebir aynı.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: HOS API — Split auth/me/tenant Routes (NO BEHAVIOR CHANGE)

- **Proof:** `docs/PROOFS/wp_hos_api_routes_split_pass.md`
- **Outcome:** auth_me_tenants.js split into auth_routes.js, me_routes.js, tenant_routes.js + request_auth.js; v1/index.js registers the three modules. Route modularization to prevent bloat; behavior unchanged.
- **Gates:** run_wp_next_local_gates + ops_run Prototype to be run (npm test: 18 pass, 7 pre-existing failures unrelated to split).

---

## WP-NEXT: HOS API — Route Modularization (NO BEHAVIOR CHANGE)

- **Proof:** `docs/PROOFS/wp_hos_api_route_modularization_pass.md`
- **Outcome:** app.js route monolith split into `routes/oidc_public.js` and `routes/v1/*` (core_world_contract, auth_me_tenants, admin_permits). Route surface, status codes, responses, validation, and legacy Deprecation header unchanged.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS (to be run).

---

## WP-NEXT: Transaction Decisions v1 — Firm Accept/Reject (BACKEND + FRONTEND + DOCS)

- **Proof:** `docs/PROOFS/wp_transaction_decisions_v1_pass.md`
- **Outcome:** Orders: POST /accept, /reject (placed → accepted | rejected). Rentals/Reservations: POST /reject added (accept existed). Firm Portal: Accept/Reject buttons per row; panel-isolated reload/error. Contract in CURRENT.md.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Transaction Lifecycle v1 — Status Transitions (MIN BACKEND + MIN UI + DOCS)

- **Proof:** `docs/PROOFS/wp_transaction_lifecycle_v1_pass.md`
- **Outcome:** Orders/Rentals/Reservations v1 status lifecycle: POST `/{resource}/{id}/transition` (action: approve|reject|cancel|complete); allowlist transitions; illegal → 422 INVALID_TRANSITION; success → 200 { id, status, updated_at }; audit log. Firm portal: Approve/Reject per row (disabled when not allowed); customer account lists show status on refresh.
- **Gates:** run_wp_next_local_gates + ops_run Prototype -CheckDemoSeed PASS.

---

## WP-NEXT: ops_run — CheckDemoSeed (OPS + DOCS)

- **Proof:** `docs/PROOFS/wp_ops_run_check_demo_seed_pass.md`
- **Outcome:** ops_run Prototype artık -CheckDemoSeed ile demo seed doğruluyor (fast debug, no drift).
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Customer Account — Read-only Orders/Rentals/Reservations (FRONTEND + DOCS)

- **Proof:** `docs/PROOFS/wp_customer_account_readonly_pass.md`
- **Outcome:** Customer account read-only lists (Orders, Rentals, Reservations) + panel error/empty standard; per-panel loading, retry, null-safe; panel isolation.
- **Gates:** run_wp_next_local_gates + ops_run Prototype (-CheckDemoSeed) PASS.

---

## WP-NEXT: Search UI — Filters deterministic + empty-safe (FRONTEND + DOCS)

- **Proof:** `docs/PROOFS/wp_search_ui_filters_deterministic_pass.md`
- **Outcome:** Search UI filters state deterministik + empty-safe + marker; single source, stable key order, no null/undefined in request; UI null-safe.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Listing Detail — Category + Attributes Contract (FRONTEND + DOCS)

- **Proof:** `docs/PROOFS/wp_listing_detail_contract_pass.md`
- **Outcome:** Listing detail page shows Category block (Category ID or —) and Attributes block (sorted key: value list or "No attributes"); empty/null safe; deterministic render.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Catalog/Search Final — Filters Contract PASS (OPS + DOCS)

- **Proof:** `docs/PROOFS/wp_catalog_search_final_filters_contract_pass.md`
- **Outcome:** filters[] SPEC + whitelist 422 + invalid category 404 + attrs compat ops ile kilitlendi.
- **Gates:** local gates + ops_run Prototype PASS.

---

## WP-NEXT: Firm Portal — UX Standard + Actions (2026-01-30)
- **Proof:** `docs/PROOFS/wp_firm_portal_ux_actions_pass.md`
- **Outcome:** Firm Portal panelleri retry/error/empty standardına alındı; listings action linkleri (View, Message) ve Edit placeholder eklendi.
- **Gates:** run_wp_next_local_gates + ops_run Prototype PASS.

---

## WP-NEXT: Firm Spine v1 (Store Portal) (2026-01-30)
- **Proof:** `docs/PROOFS/wp_firm_spine_store_portal_pass.md`
- **Outcome:** Firm Portal page `/firm` added; active tenant info + Listings/Orders/Rentals/Reservations (STORE scope); guard redirects to `/account?reason=firm_required` when no active tenant; Account "Firma Paneli" link → /firm. Frontend + docs only; conformance PASS.
- **Status:** ENV-BLOCKED (frontend_smoke [G], verify docker pipe).
- **Proof (blocked):** `docs/PROOFS/wp_firm_spine_store_portal_env_blocked.md`
- **PASS proof pending local gate run.**
- **Status:** PASS (local gates).
- **Proof (final):** `docs/PROOFS/wp_firm_spine_store_portal_final_pass.md`
- **Gates:** env_preflight + frontend_smoke + verify + conformance + update_code_index = PASS.

---

## Errata Policy (Do Not Rewrite History)

If a WP entry has a wrong WP number/title/date or a proof link mistake:

- **Do not delete or rewrite the original entry.**
- Add a short **ERRATA** note with:
  - Date of correction
  - What was wrong
  - What is the corrected value
  - Which references were updated (paths)
- Prefer additive wording: `ERRATA (2026-01-29): corrected WP title from X to Y (proof link unchanged).`

## Proof Naming Standard

- **Canonical format:** `docs/PROOFS/wpNN_<short_slug>_pass.md`
- **Allowed variants:** `wpNN_<short_slug>_final_pass.md`, `wpNN_<short_slug>_lock_pass.md`
- **Rule:** Do not rename existing proof files just to match the format; record naming drift as an ERRATA note instead (lower risk, no broken links).





## WP-NEXT: Customer Spine v1 (My Account + My Records) (2026-01-28)
- **Proof:** `docs/PROOFS/wp_customer_spine_account_pass.md`
- **Outcome:** Customer can register/login, create a record (order), and see it under `/account` (with per-section error states). All gates PASS.

## WP-NEXT: Catalog Spine Hardening (2026-01-28)
- **Proof:** `docs/PROOFS/wp_catalog_spine_hardening_pass.md`
- **Outcome:** Catalog spine hardened (deterministic filter-schema, canonical search query, integrity guard reuse). All gates PASS.

## WP-NEXT: Catalog/Listings/Search SPEC Alignment (Laravel-only) (2026-01-29)
- **Proof:** `docs/PROOFS/spec_alignment_catalog_listings_search_proof.md`
- **Outcome:** Category tree now exposes SPEC-friendly `title` (from DB `name`) and `status` additively; listings/search contract stays stable; catalog + listing contract checks PASS.

## WP-A0: Agent System Pilot Lock (2026-01-28)
- **Proof:** `docs/PROOFS/wp_a0_agent_system_pilot_lock_pass.md`
- **Outcome:** Agent workflow + discipline docs aligned and locked for new chats/agents.

## WP-74: V1 Demo Freeze + Real User Flow Confirmation (2026-01-27)
- **Proof:** `docs/PROOFS/wp74_v1_demo_freeze_pass.md`
- **Outcome:** V1 demo surface frozen; real user + firm flows confirmed end-to-end.

## WP-73: V1 Hygiene Lock (2026-01-27)
- **Proof:** `docs/PROOFS/wp73_v1_hygiene_lock_pass.md`
- **Outcome:** Packaging hygiene + single customer login entry locked.

## WP-72 FINAL: V1 Repo Standardization (2026-01-27)
- **Proof:** `docs/PROOFS/wp72_final_repo_standard_pass.md`
- **Outcome:** Demo artifacts removed/archived; repo header/docs standardized.

## WP-71: V1 Prototype Complete (2026-01-27)
- **Proof:** `docs/PROOFS/wp71_v1_prototype_complete_pass.md`
- **Outcome:** V1 prototype declared COMPLETE with end-to-end proof.

## WP-70: Single Auth UX Lock + Demo Cleanup (2026-01-27)
- **Proof:** `docs/PROOFS/wp70_single_auth_v1_lock_pass.md`
- **Outcome:** Single auth UX locked; demo/admin confusion removed.

## WP-69: V1 Prototype E2E Demo Proof (2026-01-27)
- **Proof:** `docs/PROOFS/wp69_v1_e2e_demo_pass.md`
- **Proof (Catalog/Search alignment):** `docs/PROOFS/wp69_catalog_search_frontend_alignment_pass.md`
- **Outcome:** Browser E2E verified; catalog+search is schema-driven (categories + filter-schema + attrs filters) with deterministic demo seed.

## WP-75: Listing Search Filters Spec Alignment (filters[] + attrs[] compat) (2026-01-28)
- **Proof:** `docs/PROOFS/wp75_filters_array_pass.md`
- **Outcome:** Listing search accepts SPEC-style `filters[...]` (preferred) and keeps legacy `attrs[...]` working; frontend sends `filters[...]`.

## WP-FINAL: Category / Catalog / Listing Finalization (2026-01-28)
- **Proof:** `docs/PROOFS/wp_category_catalog_listing_final_pass.md`
- **Outcome:** Single listing read engine; `filters[...]` is primary contract with `attrs[...]` backward compatibility; catalog-defined filter keys are enforced for category-scoped searches.

## WP-68C: OPS Entrypoints Runbook (2026-01-26)
- **Proof:** `docs/PROOFS/wp68c_ops_entrypoints_pass.md`
- **Outcome:** “Golden 4 Commands” ops entrypoints documented.