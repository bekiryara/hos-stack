<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Resolve Tenant Middleware
 * 
 * Resolves tenant context deterministically from header or session.
 * Sets tenant_id in request attributes for downstream use.
 */
final class ResolveTenant
{
    /**
     * Handle an incoming request
     * 
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Try X-Tenant-Id header (must be valid UUID)
        $tenantIdHeader = $request->header('X-Tenant-Id');
        if ($tenantIdHeader !== null && $tenantIdHeader !== '') {
            $tenantIdHeader = trim($tenantIdHeader);
            // Validate UUID format
            if (Str::isUuid($tenantIdHeader)) {
                $request->attributes->set('tenant_id', $tenantIdHeader);
                return $next($request);
            }
        }

        // Try session tenant_id
        $tenantIdSession = Session::get('tenant_id');
        if ($tenantIdSession !== null && $tenantIdSession !== '') {
            $tenantIdSession = trim((string) $tenantIdSession);
            if (Str::isUuid($tenantIdSession)) {
                $request->attributes->set('tenant_id', $tenantIdSession);
                return $next($request);
            }
        }

        // Leave missing (Controller will handle with TENANT_CONTEXT_MISSING error)
        return $next($request);
    }
}





