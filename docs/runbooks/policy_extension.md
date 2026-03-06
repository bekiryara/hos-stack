# Policy Extension Standard

Purpose: expand `category_flow_policy.php` without producing technical debt.

## Core Rule

Do not add category-name-based if/else in code.  
Only extend policy data and keep resolver generic.

## When to Open a New Rule

Open a new rule only if at least one of these differs from the current parent/family:

- `allowed_transaction_modes`
- `offer_variants` set
- any variant primitive:
  - `fulfillment_mode`
  - `location_scope`
  - `service_time_model`
  - `offer_requirement`
  - `pricing_strategy`
  - `billing_model`

If behavior is the same, inherit from existing parent rule.

## Change Steps

1. Update `work/pazar/config/category_flow_policy.php`
2. Run:
   - `.\ops\ops.ps1 category-flow-policy`
   - `.\ops\ops.ps1 policy-variant-matrix`
   - `.\ops\ops.ps1 listing-contract`
3. Validate UI quickly on Create Listing for affected family.
4. Update docs (`CURRENT`, `WP_CLOSEOUTS`, `PASS_LOG`) when behavior changes.

## No-Go

- No temporary per-category code patches in UI/backend.
- No duplicate rule with same behavior.
- No release with failing route/schema snapshot drift.
