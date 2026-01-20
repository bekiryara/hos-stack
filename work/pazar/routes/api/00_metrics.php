<?php

use Illuminate\Support\Facades\Route;

// Metrics endpoint (WP-31)
// GET /api/metrics - Prometheus exposition format
// Note: Laravel automatically adds /api prefix to routes in api.php
Route::get('/metrics', function (\Illuminate\Http\Request $request) {
    // Optional token protection (WP-31: if METRICS_TOKEN env var is set, require Authorization header)
    $metricsToken = env('METRICS_TOKEN');
    if ($metricsToken && !empty($metricsToken)) {
        $authHeader = $request->header('Authorization');
        if (!$authHeader || $authHeader !== "Bearer $metricsToken") {
            return response('Unauthorized', 401)
                ->header('Content-Type', 'text/plain');
        }
    }
    
    // Get environment info
    $appEnv = env('APP_ENV', 'unknown');
    $phpVersion = PHP_VERSION;
    
    // Prometheus exposition format (text/plain; version=0.0.4)
    $metrics = "# HELP pazar_up Pazar app liveness\n";
    $metrics .= "# TYPE pazar_up gauge\n";
    $metrics .= "pazar_up 1\n";
    $metrics .= "\n";
    $metrics .= "# HELP pazar_build_info Build info\n";
    $metrics .= "# TYPE pazar_build_info gauge\n";
    $metrics .= "pazar_build_info{app=\"pazar\",env=\"$appEnv\",php=\"$phpVersion\"} 1\n";
    
    return response($metrics, 200)
        ->header('Content-Type', 'text/plain; version=0.0.4');
});

