<?php

namespace App\Http\Controllers\Panel\Audit;

use Illuminate\Http\Request;

class StatusChangeLogController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\Panel\Audit\StatusChangeLogController']);
    }
}
