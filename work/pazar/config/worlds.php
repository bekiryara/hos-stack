<?php

/**
 * World Configuration
 * 
 * IMPORTANT TERMINOLOGY LOCK:
 * - This is NOT “Pazar’ın kendi içindeki world listesi”.
 * - This is a MIRROR of the H-OS world directory enablement for the stack.
 * - Pazar application itself is the `marketplace` world.
 *
 * Purpose:
 * - Governance/conformance gate input (must match work/pazar/WORLD_REGISTRY.md exactly).
 * - Prevents drift in the stack’s enabled/disabled world set.
 * 
 * Application code should NOT treat this file as a domain router.
 */

return [
    'enabled' => [
        'marketplace',
    ],
    
    'disabled' => [
        // Pazar does not own/declare other worlds here.
    ],
];








