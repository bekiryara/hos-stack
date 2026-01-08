<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Add security headers to API/auth responses.
 * Minimal CSP to avoid breaking functionality.
 */
class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);

        $path = $request->path();
        
        // Only apply to API/auth routes
        if (str_starts_with($path, 'api/') || str_starts_with($path, 'auth/')) {
            // X-Content-Type-Options: nosniff
            $response->headers->set('X-Content-Type-Options', 'nosniff');
            
            // X-Frame-Options: DENY
            $response->headers->set('X-Frame-Options', 'DENY');
            
            // Referrer-Policy: no-referrer
            $response->headers->set('Referrer-Policy', 'no-referrer');
            
            // Permissions-Policy: geolocation=(), microphone=(), camera=()
            $response->headers->set('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
            
            // Content-Security-Policy: minimal (default-src 'none'; frame-ancestors 'none'; base-uri 'none')
            $response->headers->set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'; base-uri 'none'");
        }

        return $response;
    }
}

