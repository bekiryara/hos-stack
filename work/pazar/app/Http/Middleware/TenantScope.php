<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use App\Core\MembershipClient;

/**
 * TenantScope Middleware (WP-26)
 * Enforces X-Active-Tenant-Id header presence and membership validation for store-scope endpoints.
 * WP-61B: In GENESIS mode (GENESIS_ALLOW_UNAUTH_STORE=1), membership validation is skipped when unauthenticated.
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

        // Validate tenant_id format (WP-8: store-scope endpoints require valid UUID format)
        $membershipClient = new MembershipClient();
        if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
            ], 403);
        }

        // WP-61B: In GENESIS mode, skip membership validation when unauthenticated
        $genesisAllowUnauth = env('GENESIS_ALLOW_UNAUTH_STORE', '1') === '1';
        $authToken = $request->header('Authorization');
        $isAuthenticated = !empty($authToken);

        // Membership enforcement (WP-8): Validate membership only if:
        // - Not in GENESIS mode (GENESIS_ALLOW_UNAUTH_STORE=0), OR
        // - In GENESIS mode but request is authenticated (Authorization header present)
        if (!$genesisAllowUnauth || $isAuthenticated) {
            // WP-13: Get userId from token (if available) or use genesis-default (backward compatibility)
            $userId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
            
            // Validate membership (WP-8: strict mode checks via HOS API if enabled)
            if (!$membershipClient->validateMembership($userId, $tenantIdHeader, $authToken)) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'Invalid membership or tenant access denied'
                ], 403);
            }
        }
        // In GENESIS mode with unauthenticated request: skip membership validation (format already validated)

        // Attach resolved tenant id to request attributes for handler use
        $request->attributes->set('tenant_id', $tenantIdHeader);

        return $next($request);
    }
}


