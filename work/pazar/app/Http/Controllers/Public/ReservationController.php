<?php

namespace App\Http\Controllers\Public;

use Illuminate\Http\Request;

class ReservationController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\Public\ReservationController']);
    }
}
