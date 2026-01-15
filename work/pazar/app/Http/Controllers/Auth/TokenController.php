<?php

namespace App\Http\Controllers\Auth;

use Illuminate\Http\Request;

class TokenController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\Auth\TokenController']);
    }
}
