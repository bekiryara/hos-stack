<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Auth Any Middleware
 * 
 * Allows request if user is authenticated via any method (session or bearer token).
 * For bearer token: checks if token matches HOS_OIDC_API_KEY env var (if set).
 */
final class AuthAny
{
    /**
     * Handle an incoming request
     * 
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Check if user is authenticated via session
        if (Auth::check()) {
            return $next($request);
        }

        // Check bearer token against HOS_OIDC_API_KEY (if set)
        $bearerToken = $request->bearerToken();
        if ($bearerToken !== null) {
            $apiKey = env('HOS_OIDC_API_KEY');
            if ($apiKey !== null && $apiKey !== '' && $bearerToken === $apiKey) {
                return $next($request);
            }
        }

        // Not authenticated: return 401
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) \Illuminate\Support\Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'UNAUTHORIZED',
            'message' => 'Unauthenticated.',
            'request_id' => $requestId,
        ], 401);

        return $response->header('X-Request-Id', $requestId);
    }
}






