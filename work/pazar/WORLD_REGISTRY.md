# WORLD REGISTRY

Canonical source of truth for world definitions in Pazar application.

## World Status

### Enabled Worlds
- commerce
- food
- rentals

### Disabled Worlds
- services
- real_estate
- vehicle

**Enabled Worlds (detailed):**
- `commerce` - E-commerce (Satış/Alışveriş)
- `food` - Food delivery (Yemek)
- `rentals` - Rental/Reservation (Kiralama)

**Disabled Worlds (planned but closed):**
- `services` - Services (Hizmetler)
- `real_estate` - Real Estate (Emlak)
- `vehicle` - Vehicles (Taşıtlar)

## World Definitions

### Enabled Worlds

**world_id:** `commerce`  
**label_tr:** Pazar (Satış/Alışveriş)  
**status:** enabled  
**example_categories:** Elektronik, Giyim, Ev & Yaşam, Anne & Bebek, Spor, Kitap & Hobi

**world_id:** `food`  
**label_tr:** Yemek  
**status:** enabled  
**example_categories:** Pide & Lahmacun, Döner & Kebap, Pizza, Ev Yemekleri, Tatlı, Kahvaltı

**world_id:** `rentals`  
**label_tr:** Kiralama (Rezervasyon)  
**status:** enabled  
**example_categories:** Tatil Konaklama, Araç Kiralama, Ekipman Kiralama, Etkinlik Mekânı, Depo/Ofis, Günlük Daire

### Disabled Worlds

**world_id:** `services`  
**label_tr:** Hizmetler  
**status:** disabled  
**note:** Planned but currently closed

**world_id:** `real_estate`  
**label_tr:** Emlak  
**status:** disabled  
**note:** Planned but currently closed

**world_id:** `vehicle`  
**label_tr:** Taşıtlar  
**status:** disabled  
**note:** Planned but currently closed

## Canonical Rules

- **world_id**: Immutable technical key (used in URL/contract/`subject_ref.world_id`)
- **label_tr**: UI label only (can change)
- **status**: `enabled` or `disabled` (determines if world is active)

## Contract

This registry must match `config/worlds.php` exactly. Any drift will cause conformance gate to FAIL.




