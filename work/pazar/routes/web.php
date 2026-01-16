<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'world'  => 'PAZAR',
        'status' => 'ONLINE',
        'phase'  => 'GENESIS'
    ]);
});
