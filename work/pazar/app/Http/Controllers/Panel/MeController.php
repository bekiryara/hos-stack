<?php

namespace App\Http\Controllers\Panel;

use Illuminate\Http\Request;

class MeController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\Panel\MeController']);
    }
}
