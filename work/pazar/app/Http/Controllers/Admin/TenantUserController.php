<?php

namespace App\Http\Controllers\Admin;

use Illuminate\Http\Request;

class TenantUserController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\Admin\TenantUserController']);
    }
}
