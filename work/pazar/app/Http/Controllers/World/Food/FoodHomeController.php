<?php

namespace App\Http\Controllers\World\Food;

use Illuminate\Http\Request;

class FoodHomeController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\World\Food\FoodHomeController']);
    }
}
