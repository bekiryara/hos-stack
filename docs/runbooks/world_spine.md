# World Spine Governance Runbook

## Overview

World Spine Governance Pack v1 ensures that enabled worlds have proper route/controller surfaces and ctx.world lock evidence, while disabled worlds don't have leftover controller code.

## World Activation Checklist

Before enabling a world in `config/worlds.php`, ensure:

1. **Route Surface**: At least one route file (`routes/world_<world>.php`) or controller directory exists
2. **Controller Surface**: Controller directory `app/Http/Controllers/World/<WorldName>/` exists
3. **Ctx.World Lock Evidence**: Tests or documentation show ctx.world lock usage for that world

## What Is Checked

### Enabled Worlds

For each enabled world, the check validates:

1. **Routes Surface**:
   - Routes snapshot contains routes for the world (e.g., `/commerce`, `/food`, `/rentals`)
   - OR route file exists: `routes/world_<world>.php`
   - OR controller directory exists: `app/Http/Controllers/World/<WorldName>/`

2. **Ctx.World Lock Evidence**:
   - Tests contain patterns like `ctx.world='<world>'` or `world='<world>'`
   - Documentation contains ctx.world lock references
   - This is a WARN (optional but recommended) for enabled worlds

### Disabled Worlds

For each disabled world, the check validates:

1. **No Controller Directory**:
   - Controller directory should NOT exist: `app/Http/Controllers/World/<WorldName>/`
   - If it exists, it's a FAIL (forbidden code for disabled world)

## Running Locally

### Basic Usage

```powershell
.\ops\world_spine_check.ps1
```

### Custom Paths

```powershell
.\ops\world_spine_check.ps1 `
    -WORLD_REGISTRY_PATH "work/pazar/WORLD_REGISTRY.md" `
    -WORLDS_CONFIG_PATH "work/pazar/config/worlds.php" `
    -ROUTES_SNAPSHOT "ops/snapshots/routes.pazar.json"
```

### Expected Output

```
=== WORLD SPINE GOVERNANCE CHECK ===
Timestamp: 2026-01-08 12:00:00

Config: work/pazar/config/worlds.php
Routes: ops/snapshots/routes.pazar.json

Parsing worlds config...
Enabled worlds: commerce, rentals, food
Disabled worlds: services, real_estate, vehicles

=== Checking Enabled Worlds ===

Checking world: commerce
Checking world: rentals
Checking world: food

=== Checking Disabled Worlds ===

Checking disabled world: services
Checking disabled world: real_estate
Checking disabled world: vehicles

=== WORLD SPINE CHECK RESULTS ===

World        Enabled RoutesSurface CtxWorldLock Status Notes
-----        ------- ------------- ------------ ------ -----
commerce     Yes     Yes           Yes          PASS   Route surface OK; Ctx.world lock OK
rentals      Yes     Yes           Yes          PASS   Route surface OK; Ctx.world lock OK
food         Yes     Yes           No           WARN   Route surface OK; Missing ctx.world lock evidence
services     No      N/A           N/A          PASS   No controller directory (OK for disabled world)
real_estate  No      N/A           N/A          PASS   No controller directory (OK for disabled world)
vehicles     No      N/A           N/A          PASS   No controller directory (OK for disabled world)

OVERALL STATUS: WARN (1 warnings)
```

## Fixing Failures

### Missing Route Surface

**Symptom**: Enabled world has no route/controller surface

**Fix**:
1. Create route file: `routes/world_<world>.php`
2. OR create controller directory: `app/Http/Controllers/World/<WorldName>/`
3. Add at least one route that references the world

Example:
```php
// routes/world_services.php
Route::get('/services', ServicesHomeController::class)->name('worlds.services.home');
```

### Missing Ctx.World Lock Evidence

**Symptom**: Enabled world has no ctx.world lock evidence (WARN)

**Fix**:
1. Add test with ctx.world lock:
   ```php
   // tests/Feature/WorldServicesTest.php
   $payload = ['ctx.world' => 'services', ...];
   ```

2. OR add documentation reference:
   ```markdown
   ## Services World
   Spine lock: ctx.world must be canonical at enqueue-time
   ```

### Controller Directory for Disabled World

**Symptom**: Disabled world has controller directory (FAIL)

**Fix**:
1. Remove controller directory: `app/Http/Controllers/World/<WorldName>/`
2. OR disable the world in `config/worlds.php` if it should be enabled

## Relationship to CURRENT.md

The World Activation Checklist in `CURRENT.md` outlines the process for enabling a new world. The world spine check validates that:

- **Step 1 (Route Surface)**: Routes/controllers exist for enabled worlds
- **Step 2 (Ctx.World Lock)**: Evidence of ctx.world lock usage exists
- **Step 3 (Disabled Worlds)**: No leftover code for disabled worlds

## Troubleshooting

### Routes Snapshot Not Found

If routes snapshot is missing:
1. Run `ops/routes_snapshot.ps1` to create snapshot
2. The check will fall back to filesystem checks

### Config Parsing Issues

If worlds config parsing fails:
1. Verify `config/worlds.php` syntax is correct
2. Check that enabled/disabled flags are boolean (true/false)

### False Positives

If a world is incorrectly flagged:
1. Verify route file naming: `routes/world_<world>.php`
2. Verify controller directory naming: `app/Http/Controllers/World/<WorldName>/` (capitalized)
3. Check routes snapshot is up to date

## Related Documentation

- `docs/RULES.md` - Rule 30: PR merge requires world-spine gate PASS for enabling any world
- `work/pazar/docs/runbooks/CURRENT.md` - World Activation Checklist
- `work/pazar/WORLD_REGISTRY.md` - World registry
- `work/pazar/config/worlds.php` - Worlds configuration
- `ops/world_spine_check.ps1` - World spine check script
- `.github/workflows/world-spine.yml` - CI workflow

