<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use App\Core\MembershipClient;

/**
 * TenantScope Middleware (WP-26)
 * Enforces X-Active-Tenant-Id header presence and membership validation for store-scope endpoints.
 */
class TenantScope
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Require X-Active-Tenant-Id header
        $tenantIdHeader = $request->header('X-Active-Tenant-Id');
        if (!$tenantIdHeader) {
            return response()->json([
                'error' => 'missing_header',
                'message' => 'X-Active-Tenant-Id header is required'
            ], 400);
        }

        // Membership enforcement (WP-8): Validate tenant_id format and membership
        // WP-13: Get userId from token (if available) or use genesis-default (backward compatibility)
        $membershipClient = new MembershipClient();
        $userId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
        $authToken = $request->header('Authorization'); // Forward Authorization header for strict mode

        // Validate tenant_id format (WP-8: store-scope endpoints require valid UUID format)
        if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
            ], 403);
        }

        // Validate membership (WP-8: strict mode checks via HOS API if enabled)
        if (!$membershipClient->validateMembership($userId, $tenantIdHeader, $authToken)) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'Invalid membership or tenant access denied'
            ], 403);
        }

        // Attach resolved tenant id to request attributes for handler use
        $request->attributes->set('tenant_id', $tenantIdHeader);

        return $next($request);
    }
}


