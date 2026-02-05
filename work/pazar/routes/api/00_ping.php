<?php

use Illuminate\Support\Facades\Route;

// Ping endpoint
Route::get('/ping', function () {
    return response()->json([
        'api'  => 'PAZAR',
        'ping' => 'OK'
    ]);
});

// Compatibility alias: /v1/ping (most API checks use /api/v1/*)
Route::get('/v1/ping', function () {
    return response()->json([
        'api'  => 'PAZAR',
        'ping' => 'OK'
    ]);
});
