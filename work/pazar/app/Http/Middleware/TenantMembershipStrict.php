<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use App\Core\MembershipClient;

/**
 * TenantMembershipStrict (WP-NEXT: Store Scope AuthZ v2)
 * Enforces tenant boundary + HOS membership for transaction decision endpoints (accept/reject).
 * Run after tenant.scope (which sets tenant_id on request). GENESIS flexibility stays in tenant.scope.
 */
class TenantMembershipStrict
{
    public function handle(Request $request, Closure $next): Response
    {
        $tenantId = $request->attributes->get('tenant_id');
        if ($tenantId === null || $tenantId === '') {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'tenant scope required'
            ], 400);
        }

        $authHeader = $request->header('Authorization');
        if (!$authHeader || !preg_match('/^Bearer\s+.+/i', $authHeader)) {
            return response()->json([
                'error' => 'UNAUTHORIZED',
                'message' => 'Authorization required'
            ], 401);
        }

        $membershipClient = new MembershipClient();
        $result = $membershipClient->checkMembershipViaHos($tenantId, $authHeader);

        if ($result === null) {
            return response()->json([
                'error' => 'HOS_UNAVAILABLE',
                'message' => 'membership check failed'
            ], 503);
        }

        if (($result['allowed'] ?? false) !== true) {
            return response()->json([
                'error' => 'FORBIDDEN',
                'message' => 'tenant membership required'
            ], 403);
        }

        return $next($request);
    }
}
