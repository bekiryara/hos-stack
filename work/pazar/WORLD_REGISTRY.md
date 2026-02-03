# WORLD REGISTRY

Canonical mirror of the H-OS world directory enablement for this stack.

IMPORTANT:
- Pazar application itself is the `marketplace` world.
- This file exists for governance/conformance and must match `work/pazar/config/worlds.php` exactly.
- Do not interpret this as “Pazar manages all worlds internally”.

## World Status

### Enabled Worlds
- marketplace

### Disabled Worlds
<!-- None (Pazar does not declare other worlds here) -->

**Enabled Worlds (detailed):**
- `marketplace` - Marketplace (Pazar)
  - Verticals (catalog roots): vehicle, real-estate, service
 
Other worlds (e.g. `messaging`, `social`) are owned by the H-OS world directory and are not declared here.

## World Definitions

### Enabled Worlds

**world_id:** `marketplace`  
**label_tr:** Pazar  
**status:** enabled  
**verticals (catalog roots):** vehicle, real-estate, service

### Disabled Worlds
<!-- None (Pazar does not declare other worlds here) -->

## Canonical Rules

- **world_id**: Immutable technical key (used in URL/contract/`subject_ref.world_id`)
- **label_tr**: UI label only (can change)
- **status**: `enabled` or `disabled` (determines if world is active)

## Contract

This registry must match `config/worlds.php` exactly. Any drift will cause conformance gate to FAIL.




