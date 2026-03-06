# Primitive Matrix v1

Date: 2026-03-06  
Status: Active contract source for policy behavior families.

## Purpose

This matrix defines canonical behavior families independent from category count.
Each `offer_variant` in `category_flow_policy.php` must map to one row here.

## Columns

- `rule`: policy rule family key
- `variant`: offer_variant key
- `transaction_mode`: sale | rental | reservation
- `interaction_mode`: flow | contact_only
- `pricing_strategy`: base_only | offer_only
- `billing_model`: one_time | per_day | per_person | per_hour
- `service_time_model`: none | date_range | slot | session
- `location_scope`: none | city | point | service_area
- `offer_requirement`: no_offer | optional_offer | required_offer

## Matrix

| rule | variant | transaction_mode | interaction_mode | pricing_strategy | billing_model | service_time_model | location_scope | offer_requirement |
|---|---|---|---|---|---|---|---|---|
| vehicle | sale | sale | contact_only | base_only | one_time | none | point | no_offer |
| vehicle | rental | rental | flow | base_only | per_day | date_range | point | no_offer |
| konut | sale | sale | contact_only | base_only | one_time | none | point | no_offer |
| konut | rental | rental | contact_only | base_only | per_day | date_range | point | no_offer |
| konut | turistik_gunluk_kiralik | reservation | flow | base_only | per_day | slot | point | optional_offer |
| konut | devren_satilik_konut | sale | contact_only | base_only | one_time | none | point | no_offer |
| is-yeri | sale | sale | contact_only | base_only | one_time | none | point | no_offer |
| is-yeri | rental | rental | contact_only | base_only | per_day | date_range | point | no_offer |
| is-yeri | devren_satilik | sale | contact_only | base_only | one_time | none | point | no_offer |
| is-yeri | devren_kiralik | rental | contact_only | base_only | per_day | date_range | point | no_offer |
| service-product | sale | sale | flow | base_only | one_time | none | point | no_offer |
| events | reservation | reservation | flow | base_only | per_person | slot | point | optional_offer |
| events | reservation_hourly | reservation | flow | base_only | per_hour | slot | point | optional_offer |
| events | reservation_session | reservation | flow | base_only | per_session | session | point | optional_offer |
| food | sale | sale | flow | base_only | one_time | none | service_area | no_offer |

## Governance

1. Behavior change must start with this matrix row update.
2. Then update `category_flow_policy.php`.
3. `ops/_checks/policy_variant_matrix_check.ps1` must pass before merge.
4. Create/Edit UI can only render behavior derived from effective policy.
