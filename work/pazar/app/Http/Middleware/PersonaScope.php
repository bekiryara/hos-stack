<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * PersonaScope Middleware (WP-8)
 * Enforces persona-based header requirements according to SPEC §5.2-§5.3.
 * 
 * Persona types:
 * - GUEST: No headers required (allows unauthenticated access)
 * - PERSONAL: Authorization header REQUIRED (401 AUTH_REQUIRED if missing)
 * - STORE: X-Active-Tenant-Id header REQUIRED (delegates to TenantScope middleware)
 */
class PersonaScope
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  $persona  Persona type: 'guest', 'personal', or 'store'
     */
    public function handle(Request $request, Closure $next, string $persona = 'guest'): Response
    {
        $persona = strtolower($persona);

        // GUEST: No headers required, allow request
        if ($persona === 'guest') {
            return $next($request);
        }

        // PERSONAL: Require Authorization header (SPEC §5.2)
        if ($persona === 'personal') {
            $authHeader = $request->header('Authorization');
            
            if (!$authHeader) {
                return response()->json([
                    'error' => 'AUTH_REQUIRED',
                    'message' => 'Authorization header is required for personal-scope operations'
                ], 401);
            }

            // Validate Bearer token format (basic check)
            if (!preg_match('/^Bearer\s+.+$/i', $authHeader)) {
                return response()->json([
                    'error' => 'AUTH_REQUIRED',
                    'message' => 'Authorization header must be in Bearer token format'
                ], 401);
            }

            // Continue to next middleware (AuthContext will verify JWT if needed)
            return $next($request);
        }

        // STORE: Require X-Active-Tenant-Id header
        // Note: This middleware should be used in combination with TenantScope middleware
        // TenantScope handles full validation (format, membership)
        if ($persona === 'store') {
            $tenantIdHeader = $request->header('X-Active-Tenant-Id');
            
            if (!$tenantIdHeader) {
                return response()->json([
                    'error' => 'missing_header',
                    'message' => 'X-Active-Tenant-Id header is required for store-scope operations'
                ], 400);
            }

            // Continue to next middleware (TenantScope will validate format and membership)
            return $next($request);
        }

        // Unknown persona type
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => "Unknown persona type: {$persona}"
        ], 500);
    }
}


