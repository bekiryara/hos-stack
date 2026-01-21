<?php

/**
 * World Configuration
 * 
 * Canonical source of truth for enabled/disabled worlds.
 * Must match work/pazar/WORLD_REGISTRY.md exactly.
 * 
 * This file is used for governance/conformance checks.
 * Application code may use this config or maintain its own source.
 */

return [
    'enabled' => [
        'marketplace',
    ],
    
    'disabled' => [
        'messaging',
        'social',
    ],
];








