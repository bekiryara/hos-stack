<?php

use Illuminate\Support\Facades\Route;

// Ping endpoint
Route::get('/ping', function () {
    return response()->json([
        'api'  => 'PAZAR',
        'ping' => 'OK'
    ]);
});
