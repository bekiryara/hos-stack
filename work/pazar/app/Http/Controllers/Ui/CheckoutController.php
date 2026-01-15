<?php

namespace App\Http\Controllers\Ui;

use Illuminate\Http\Request;

class CheckoutController extends \App\Http\Controllers\Controller
{
    public function __invoke(Request $request)
    {
        return response()->json(['ok' => true, 'controller' => 'App\Http\Controllers\Ui\CheckoutController']);
    }
}
