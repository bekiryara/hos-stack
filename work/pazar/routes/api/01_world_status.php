<?php

use Illuminate\Support\Facades\Route;
use App\Worlds\WorldRegistry;

// GENESIS World Status (SPEC ?24.4, WP-1)
Route::get('/world/status', function () {
    $registry = new WorldRegistry();
    $worldKey = 'marketplace';
    
    // Check if marketplace world is enabled
    // WorldRegistry uses 'marketplace' as world ID (not 'commerce')
    $isEnabled = $registry->isEnabled('marketplace');
    
    // Read version from VERSION file or env (minimal: use env or default)
    $version = env('APP_VERSION', '1.4.0');
    $phase = 'GENESIS';
    
    // Optional: commit hash (if available)
    $commit = env('GIT_COMMIT', null);
    if ($commit) {
        $commit = substr($commit, 0, 7); // short SHA
    }
    
    // If world is disabled, return 503 + WORLD_DISABLED (SPEC ?17.5)
    if (!$isEnabled) {
        return response()->json([
            'error_code' => 'WORLD_DISABLED',
            'message' => "World '{$worldKey}' is disabled",
            'world_key' => $worldKey
        ], 503);
    }
    
    // Build response (SPEC ?24.4 format)
    $response = [
        'world_key' => $worldKey,
        'availability' => 'ONLINE',
        'phase' => $phase,
        'version' => $version
    ];
    
    // Add commit if available
    if ($commit) {
        $response['commit'] = $commit;
    }
    
    return response()->json($response);
});



