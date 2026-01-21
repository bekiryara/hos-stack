# WORLD REGISTRY

Canonical source of truth for world definitions in Pazar application.

## World Status

### Enabled Worlds
- marketplace

### Disabled Worlds
- messaging
- social

**Enabled Worlds (detailed):**
- `marketplace` - Marketplace (Pazar)
  - Verticals: commerce (E-commerce), food (Food delivery), rentals (Rental/Reservation)

**Disabled Worlds (planned but closed):**
- `messaging` - Mesajlaşma
- `social` - Sosyal

## World Definitions

### Enabled Worlds

**world_id:** `marketplace`  
**label_tr:** Pazar  
**status:** enabled  
**verticals:** commerce (E-commerce), food (Food delivery), rentals (Rental/Reservation)

### Disabled Worlds

**world_id:** `messaging`  
**label_tr:** Mesajlaşma  
**status:** disabled  
**note:** Planned but currently closed

**world_id:** `social`  
**label_tr:** Sosyal  
**status:** disabled  
**note:** Planned but currently closed

## Canonical Rules

- **world_id**: Immutable technical key (used in URL/contract/`subject_ref.world_id`)
- **label_tr**: UI label only (can change)
- **status**: `enabled` or `disabled` (determines if world is active)

## Contract

This registry must match `config/worlds.php` exactly. Any drift will cause conformance gate to FAIL.




