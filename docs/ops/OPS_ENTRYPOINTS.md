# OPS Entrypoints (WP-68)

**Purpose:** Single source of truth for "what to run" in ops scripts. Eliminates confusion about which script to run when.

**Principle:** Do not run random scripts. Use the entrypoints below.

---

## Tier-0: Daily Entrypoints

**Run these daily or before important operations.**

### `ops/ops_run.ps1`
**Single daily ops entrypoint.**

```powershell
.\ops\ops_run.ps1              # Prototype profile (default, minimal)
.\ops\ops_run.ps1 -Profile Full  # Full profile (Prototype + ops_status)
```

**Prototype profile runs:**
- Secret scan
- Public ready check
- Conformance
- Prototype verification

**Full profile runs:**
- All Prototype checks
- Plus `ops_status.ps1` (comprehensive dashboard)

**When to use:**
- Daily: Run Prototype profile
- Before release: Run Full profile
- Quick health check: Prototype profile

---

### `ops/ship_main.ps1`
**Publish to main branch.**

```powershell
.\ops\ship_main.ps1
```

**What it does:**
- Runs all gates and smoke tests
- Pushes to main if all checks pass
- Exits with error if any gate fails

**When to use:**
- When ready to publish changes to main
- After all local tests pass

---

### `ops/prototype_v1.ps1`
**Quick prototype/demo verification.**

```powershell
.\ops\prototype_v1.ps1
```

**What it does:**
- Runs frontend smoke test
- Runs world status check
- Verifies prototype environment is ready

**When to use:**
- After setting up development environment
- Before demonstrating prototype
- Quick verification that demo is ready

---

### `ops/doctor.ps1`
**Repository health doctor.**

```powershell
.\ops\doctor.ps1
```

**What it does:**
- Checks Docker Compose services
- Checks H-OS and Pazar health
- Checks for tracked secrets
- Checks repository integrity

**When to use:**
- Troubleshooting issues
- Health check before important operations
- When something seems wrong

---

## Tier-1: Contract Gates

**Do NOT run directly unless instructed by senior engineer or specific troubleshooting guide.**

These scripts verify API contracts and should only be run as part of gates or troubleshooting.

**Examples:**
- `ops/account_portal_contract_check.ps1`
- `ops/listing_contract_check.ps1`
- `ops/messaging_contract_check.ps1`
- `ops/product_contract_check.ps1`
- `ops/rental_contract_check.ps1`
- `ops/reservation_contract_check.ps1`
- `ops/order_contract_check.ps1`
- `ops/offer_contract_check.ps1`
- `ops/boundary_contract_check.ps1`
- `ops/catalog_contract_check.ps1`
- `ops/core_persona_contract_check.ps1`
- `ops/persona_scope_check.ps1`
- `ops/tenant_scope_contract_check.ps1`

**When to use:**
- As part of `ops_status.ps1` (automatically run)
- When troubleshooting specific API contract issues
- When instructed by senior engineer

---

## Tier-2: Seeds and Tools

**Do NOT run directly unless you know what you're doing.**

These scripts seed demo data or perform specific utility operations.

**Examples:**
- `ops/demo_seed.ps1`
- `ops/demo_seed_root_listings.ps1`
- `ops/demo_seed_showcase.ps1`
- `ops/demo_seed_transaction_modes.ps1`
- `ops/ensure_demo_membership.ps1`
- `ops/ensure_product_test_auth.ps1`

**When to use:**
- Setting up demo environment
- Resetting demo data
- When explicitly instructed

---

## Decision Table

| Scenario | Command | Notes |
|----------|---------|-------|
| Daily health check | `.\ops\ops_run.ps1` | Prototype profile (default) |
| Before release | `.\ops\ops_run.ps1 -Profile Full` | Full profile includes ops_status |
| Quick prototype check | `.\ops\prototype_v1.ps1` | Fast verification |
| Troubleshooting | `.\ops\doctor.ps1` | Repository health check |
| Ready to publish | `.\ops\ship_main.ps1` | Runs all gates before push |
| Comprehensive status | `.\ops\ops_status.ps1` | Full dashboard (or use Full profile) |

---

## Rules

1. **Do NOT run random scripts** - Use entrypoints above
2. **Tier-1 scripts** (contract checks) are called by `ops_status.ps1` automatically
3. **Tier-2 scripts** (seeds/tools) require explicit instruction
4. **When in doubt** - Use `ops_run.ps1` Prototype profile

---

## See Also

- `docs/runbooks/OPS_ENTRYPOINTS.md` - Detailed runbook (WP-68C)
- `ops/ops_status.ps1` - Comprehensive status dashboard

