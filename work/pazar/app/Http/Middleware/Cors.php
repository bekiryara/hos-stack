<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * CORS middleware with environment-based allowlist.
 * DEV: allow all origins or localhost allowlist
 * PROD: strict allowlist from env var CORS_ALLOWED_ORIGINS
 */
class Cors
{
    public function handle(Request $request, Closure $next): Response
    {
        // Handle preflight OPTIONS requests
        if ($request->getMethod() === 'OPTIONS') {
            return $this->handlePreflight($request);
        }

        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);

        // Apply CORS headers to API/auth routes
        $path = $request->path();
        if (str_starts_with($path, 'api/') || str_starts_with($path, 'auth/')) {
            $origin = $request->header('Origin');
            
            if ($this->isOriginAllowed($origin)) {
                $response->headers->set('Access-Control-Allow-Origin', $origin);
            }
            
            $response->headers->set('Access-Control-Allow-Credentials', 'false');
            $response->headers->set('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
            $response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept');
            $response->headers->set('Access-Control-Max-Age', '86400');
        }

        return $response;
    }

    protected function handlePreflight(Request $request): Response
    {
        $path = $request->path();
        if (!str_starts_with($path, 'api/') && !str_starts_with($path, 'auth/')) {
            return response('', 204);
        }

        $origin = $request->header('Origin');
        $headers = new \Symfony\Component\HttpFoundation\ResponseHeaderBag();
        
        if ($this->isOriginAllowed($origin)) {
            $headers->set('Access-Control-Allow-Origin', $origin);
        }
        
        $headers->set('Access-Control-Allow-Credentials', 'false');
        $headers->set('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
        $headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept');
        $headers->set('Access-Control-Max-Age', '86400');

        return response('', 204, $headers->all());
    }

    protected function isOriginAllowed(?string $origin): bool
    {
        if (empty($origin)) {
            return false;
        }

        $env = config('app.env');
        
        // DEV: allow all origins or localhost allowlist
        if ($env === 'local' || $env === 'dev') {
            // Allow localhost variants
            if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1|::1)(:\d+)?$/', $origin)) {
                return true;
            }
            // In dev, allow all (can be restricted later)
            return true;
        }
        
        // PROD: strict allowlist from env var CORS_ALLOWED_ORIGINS
        $allowedOrigins = env('CORS_ALLOWED_ORIGINS', '');
        if (empty($allowedOrigins)) {
            return false;
        }
        
        $allowedList = array_map('trim', explode(',', $allowedOrigins));
        return in_array($origin, $allowedList, true);
    }
}

