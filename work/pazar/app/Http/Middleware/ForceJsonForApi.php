<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Force JSON response for /api/* and /auth/* routes.
 * Sets Accept header to application/json so Laravel returns JSON instead of HTML.
 */
class ForceJsonForApi
{
    public function handle(Request $request, Closure $next): Response
    {
        $path = $request->path();
        
        if (str_starts_with($path, 'api/') || str_starts_with($path, 'auth/')) {
            $request->headers->set('Accept', 'application/json');
            $request->headers->set('X-Requested-With', 'XMLHttpRequest');
        }

        return $next($request);
    }
}

