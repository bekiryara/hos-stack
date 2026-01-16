<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Ensure Tenant User Middleware
 * 
 * Ensures tenant_id is present (must run after resolve.tenant and auth.any).
 * Returns 403 if tenant context is missing.
 */
final class EnsureTenantUser
{
    /**
     * Handle an incoming request
     * 
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $tenantId = $request->attributes->get('tenant_id');

        if (empty($tenantId)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) \Illuminate\Support\Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Tenant context required.',
                'request_id' => $requestId,
            ], 403);

            return $response->header('X-Request-Id', $requestId);
        }

        return $next($request);
    }
}





