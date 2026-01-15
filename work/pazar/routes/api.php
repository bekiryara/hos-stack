<?php

use Illuminate\Support\Facades\Route;

Route::get('/ping', function () {
    return response()->json([
        'api'  => 'PAZAR',
        'ping' => 'OK'
    ]);
});
