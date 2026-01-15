<?php

namespace App\Http\Controllers\World\Rentals;

use Illuminate\Http\Request;

class RentalsHomeController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\World\Rentals\RentalsHomeController']);
    }
}
