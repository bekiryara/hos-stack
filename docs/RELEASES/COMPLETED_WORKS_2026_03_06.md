# Completed Works (Commit-Certified)

Date: 2026-03-06  
Scope: `2026-03-01 .. 2026-03-06` (plus required backbone commits)

## Purpose

This file is the single "what is actually done" index.  
Each item below is backed by merged commits on `main`.

## 1) Deterministic policy/variant backbone (completed)

- `73a335c` policy: make primitives variant-level deterministic across backend and create form
- `7e90a09` fix(policy): preserve variant primitives in intent resolver
- `14941fe` pazar: enforce service primitives across listing and transaction flows
- `0ebea20` ops: add variant matrix gate + policy extension standards

Outcome:
- Effective primitives now derive from selected `offer_variant` in a deterministic way.
- Policy matrix checks exist to prevent silent drift.

## 2) HOS-only address transition (completed)

- `65c4d73` hos: address dictionary schema/routes/import
- `de765cd` pazar: route address options via HOS and remove legacy address artifacts
- `32fe2d6` web: tenant address flows for firm and listing
- `5c57e67` fix: create-listing tenant address preload
- `839fde1` fix: tenant address autofill (district/neighborhood)
- `e377249` pazar: normalized listing location; runtime `location_json` dependency removed

Outcome:
- Address option source is HOS.
- Listing location write/read is normalized (no runtime dependence on legacy location json).

## 3) Create/Edit parity and policy-bound UI (completed)

- `3e74f30` ui(edit): align with create form and simplify location inputs
- `40d98aa` create(v2): bind canonical pricing and schedule to policy primitives
- `47bf7cf` ui(create): complete pricing/time binding and remove duplicate primitive rows

Outcome:
- Create/Edit share same policy-driven behavior baseline.
- Duplicate/contradictory primitive rendering reduced.

## 4) Pricing Engine v1 + totals snapshot (completed)

- `16f3463` pricing(v1): deterministic unit/multiplier/total snapshot across flows
- `a9fb3bf` ui+api: totals-first pricing for rental/reservation detail and panel rows
- `2108478` ui: unified transaction pricing cards
- `bd2f786` pricing: persist rental/reservation totals snapshot; remove read fallback

Related foundations:
- `d6c3848`, `9f932c3`, `b5922f3`, `f2e0b49`, `7b0e971`

Outcome:
- Transactions have deterministic pricing snapshots.
- Rental/Reservation totals are persisted and consumed directly.

## 5) Search contract hardening (completed)

- `69505d5` search: retire `attrs[...]`, enforce `filters[...]` only
- `8fdbf3f` search-ui: remove legacy `f_*` fallback, keep filters-only hydration

Outcome:
- Query contract is single-source and less ambiguous.

## 6) Check hygiene / ops hardening (completed)

- `6df3ee9` checks(order): stable idempotency keys prevent repeated growth
- `6e3b9c6` checks+docs: standardize contract-check cleanup

Outcome:
- Contract checks are more repeatable and produce less residue.

## 7) Firm UX boundary (completed)

- `070f6b3` add firm settings page; separate account vs firm management
- `920c6aa` fix account portal text encoding cleanup

Outcome:
- Firm concerns moved out of generic account surface.

## 8) Repo hygiene (completed)

- `88aa944` remove temporary root tmp artifacts
- `f95febb` remove dead legacy error envelope conversion path

Outcome:
- Reduced dead/temporary paths that create analysis noise.

## Open items (not marked complete)

- Legacy/test residue cleanup in transaction lists (`not_found` historical rows).
- Phase-2 parity expansion for richer pricing/time inputs (without new ad-hoc if/else).
- Final transaction UX label/state matrix lock.

