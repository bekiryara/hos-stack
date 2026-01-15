<?php

namespace App\Http\Controllers\World\Commerce;

use Illuminate\Http\Request;

class CommerceHomeController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\World\Commerce\CommerceHomeController']);
    }
}
