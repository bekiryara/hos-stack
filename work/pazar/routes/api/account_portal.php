<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// WP-NEXT: Store-scope authz hardening â€” require Authorization + HOS membership for tenant-bound reads.
/**
 * Enforce store-scope authz: X-Active-Tenant-Id + Authorization + HOS membership (me).
 * Returns a JSON response to return (4xx/5xx) or null if authorized.
 *
 * @param \Illuminate\Http\Request $request
 * @param \App\Core\MembershipClient $membershipClient
 * @param string $tenantIdParam Value of tenant param (seller_tenant_id or provider_tenant_id)
 * @return \Illuminate\Http\JsonResponse|null
 */
function requireStoreScopeAuthz(\Illuminate\Http\Request $request, \App\Core\MembershipClient $membershipClient, string $tenantIdParam): ?\Illuminate\Http\JsonResponse
{
    $tenantIdHeader = $request->header('X-Active-Tenant-Id');
    if ($tenantIdHeader === null || $tenantIdHeader === '') {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'X-Active-Tenant-Id header is required for store scope'
        ], 400);
    }
    if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'X-Active-Tenant-Id must be a valid UUID'
        ], 422);
    }
    if ($tenantIdHeader !== $tenantIdParam) {
        return response()->json([
            'error' => 'FORBIDDEN',
            'message' => 'X-Active-Tenant-Id header must match tenant parameter'
        ], 403);
    }
    $authHeader = $request->header('Authorization');
    if (!$authHeader || !preg_match('/^Bearer\s+.+/i', $authHeader)) {
        return response()->json([
            'error' => 'UNAUTHORIZED',
            'message' => 'Authorization: Bearer token is required for store scope'
        ], 401);
    }
    $result = $membershipClient->checkMembershipViaHos($tenantIdParam, $authHeader);
    if ($result === null) {
        return response()->json([
            'error' => 'AUTHZ_UNAVAILABLE',
            'message' => 'Membership check unavailable (HOS timeout or error)'
        ], 503);
    }
    if (($result['allowed'] ?? false) !== true) {
        return response()->json([
            'error' => 'FORBIDDEN',
            'message' => 'Invalid membership or tenant access denied'
        ], 403);
    }
    return null;
}

// WP-12: Account Portal Read Endpoints (Read-Only)

// WP-12.1: GET /v1/orders - List orders (Personal or Store scope)
// WP-13: auth.ctx middleware extracts requester_user_id if Authorization header exists (optional for store scope)
Route::middleware('auth.ctx')->get('/v1/orders', function (\Illuminate\Http\Request $request) {
    try {
        // Require at least one filter (buyer_user_id or seller_tenant_id)
        if (!$request->has('buyer_user_id') && !$request->has('seller_tenant_id')) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'Either buyer_user_id or seller_tenant_id parameter is required'
            ], 422);
        }
        
        $query = DB::table('orders')
            ->leftJoin('listings', 'orders.listing_id', '=', 'listings.id');
        
        // Personal scope: Filter by buyer_user_id (WP-13: requires Authorization token)
        if ($request->has('buyer_user_id')) {
            // WP-13: Personal scope requires Authorization token
            $tokenUserId = $request->attributes->get('requester_user_id');
            $buyerUserId = $request->input('buyer_user_id');
            
            // Require Authorization token for personal scope
            if (!$tokenUserId) {
                return response()->json([
                    'error' => 'AUTH_REQUIRED',
                    'message' => 'Authorization: Bearer token is required for personal scope queries'
                ], 401);
            }
            
            // Verify token's user ID matches query parameter (security: users can only query their own data)
            if ($tokenUserId !== $buyerUserId) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'Cannot query orders for other users (token user_id must match buyer_user_id)'
                ], 403);
            }
            
            $query->where('orders.buyer_user_id', $buyerUserId);
        }
        
        // Store scope: Filter by seller_tenant_id (WP-NEXT: auth + HOS membership required)
        if ($request->has('seller_tenant_id')) {
            $sellerTenantId = $request->input('seller_tenant_id');
            $membershipClient = new \App\Core\MembershipClient();
            $err = requireStoreScopeAuthz($request, $membershipClient, $sellerTenantId);
            if ($err !== null) {
                return $err;
            }
            $query->where('orders.seller_tenant_id', $sellerTenantId);
        }
        
        // Pagination (WP-12.1: per_page default 20, max 50)
        $page = max(1, (int)$request->input('page', 1));
        $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
        $offset = ($page - 1) * $perPage;
        
        // Get total count before pagination
        $total = $query->count();
        
        $orders = $query->select('orders.*', 'listings.title as listing_title')
            ->orderBy('orders.created_at', 'desc')
            ->offset($offset)
            ->limit($perPage)
            ->get()
            ->map(function ($order) {
                return [
                    'id' => $order->id,
                    'listing_id' => $order->listing_id,
                    'listing_title' => $order->listing_title ?? null,
                    'buyer_user_id' => $order->buyer_user_id,
                    'seller_tenant_id' => $order->seller_tenant_id,
                    'quantity' => $order->quantity,
                    'status' => $order->status,
                    'totals' => $order->totals_json ? json_decode($order->totals_json, true) : null,
                    'created_at' => $order->created_at,
                    'updated_at' => $order->updated_at
                ];
            });
        
        // WP-12.1: Response envelope format {data, meta}
        return response()->json([
            'data' => $orders,
            'meta' => [
                'total' => $total,
                'page' => $page,
                'per_page' => $perPage,
                'total_pages' => (int) ceil($total / $perPage)
            ]
        ]);
    } catch (\Exception $e) {
        \Log::error('GET /v1/orders error: ' . $e->getMessage(), ['exception' => $e]);
        return response()->json([
            'error' => 'INTERNAL_ERROR',
            'message' => 'Server error occurred while processing request'
        ], 500);
    }
});

// WP-12.1: GET /v1/rentals - List rentals (Personal or Store scope)
// WP-13: auth.ctx middleware extracts requester_user_id if Authorization header exists (optional for store scope)
Route::middleware('auth.ctx')->get('/v1/rentals', function (\Illuminate\Http\Request $request) {
    try {
        // Require at least one filter (renter_user_id or provider_tenant_id)
        if (!$request->has('renter_user_id') && !$request->has('provider_tenant_id')) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'Either renter_user_id or provider_tenant_id parameter is required'
            ], 422);
        }
        
        $query = DB::table('rentals')
            ->leftJoin('listings', 'rentals.listing_id', '=', 'listings.id');
        
        // Personal scope: Filter by renter_user_id (WP-13: requires Authorization token)
        if ($request->has('renter_user_id')) {
            // WP-13: Personal scope requires Authorization token
            $tokenUserId = $request->attributes->get('requester_user_id');
            $renterUserId = $request->input('renter_user_id');
            
            // Require Authorization token for personal scope
            if (!$tokenUserId) {
                return response()->json([
                    'error' => 'AUTH_REQUIRED',
                    'message' => 'Authorization: Bearer token is required for personal scope queries'
                ], 401);
            }
            
            // Verify token's user ID matches query parameter (security: users can only query their own data)
            if ($tokenUserId !== $renterUserId) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'Cannot query rentals for other users (token user_id must match renter_user_id)'
                ], 403);
            }
            
            $query->where('rentals.renter_user_id', $renterUserId);
        }
        
        // Store scope: Filter by provider_tenant_id (WP-NEXT: auth + HOS membership required)
        if ($request->has('provider_tenant_id')) {
            $providerTenantId = $request->input('provider_tenant_id');
            $membershipClient = new \App\Core\MembershipClient();
            $err = requireStoreScopeAuthz($request, $membershipClient, $providerTenantId);
            if ($err !== null) {
                return $err;
            }
            $query->where('rentals.provider_tenant_id', $providerTenantId);
        }
        
        // Pagination (WP-12.1: per_page default 20, max 50)
        $page = max(1, (int)$request->input('page', 1));
        $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
        $offset = ($page - 1) * $perPage;
        
        // Get total count before pagination
        $total = $query->count();
        
        $rentals = $query->select('rentals.*', 'listings.title as listing_title')
            ->orderBy('rentals.created_at', 'desc')
            ->offset($offset)
            ->limit($perPage)
            ->get()
            ->map(function ($rental) {
                return [
                    'id' => $rental->id,
                    'listing_id' => $rental->listing_id,
                    'listing_title' => $rental->listing_title ?? null,
                    'renter_user_id' => $rental->renter_user_id,
                    'provider_tenant_id' => $rental->provider_tenant_id,
                    'pricing_source' => $rental->pricing_source ?? null,
                    'price_amount' => $rental->price_amount ?? null,
                    'price_currency' => $rental->price_currency ?? null,
                    'billing_model' => $rental->billing_model ?? null,
                    'totals' => $rental->totals_json ? json_decode($rental->totals_json, true) : null,
                    'start_at' => $rental->start_at,
                    'end_at' => $rental->end_at,
                    'status' => $rental->status,
                    'created_at' => $rental->created_at,
                    'updated_at' => $rental->updated_at
                ];
            });
        
        // WP-12.1: Response envelope format {data, meta}
        return response()->json([
            'data' => $rentals,
            'meta' => [
                'total' => $total,
                'page' => $page,
                'per_page' => $perPage,
                'total_pages' => (int) ceil($total / $perPage)
            ]
        ]);
    } catch (\Exception $e) {
        \Log::error('GET /v1/rentals error: ' . $e->getMessage(), ['exception' => $e]);
        return response()->json([
            'error' => 'INTERNAL_ERROR',
            'message' => 'Server error occurred while processing request'
        ], 500);
    }
});

// WP-12.1: GET /v1/reservations - List reservations (Personal or Store scope)
// WP-13: auth.ctx middleware extracts requester_user_id if Authorization header exists (optional for store scope)
Route::middleware('auth.ctx')->get('/v1/reservations', function (\Illuminate\Http\Request $request) {
    try {
        // Require at least one filter (requester_user_id or provider_tenant_id)
        if (!$request->has('requester_user_id') && !$request->has('provider_tenant_id')) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'Either requester_user_id or provider_tenant_id parameter is required'
            ], 422);
        }
        
        $query = DB::table('reservations')
            ->leftJoin('listings', 'reservations.listing_id', '=', 'listings.id');
        
        // Personal scope: Filter by requester_user_id (WP-13: requires Authorization token)
        if ($request->has('requester_user_id')) {
            // WP-13: Personal scope requires Authorization token
            $tokenUserId = $request->attributes->get('requester_user_id');
            $requesterUserId = $request->input('requester_user_id');
            
            // Require Authorization token for personal scope
            if (!$tokenUserId) {
                return response()->json([
                    'error' => 'AUTH_REQUIRED',
                    'message' => 'Authorization: Bearer token is required for personal scope queries'
                ], 401);
            }
            
            // Verify token's user ID matches query parameter (security: users can only query their own data)
            if ($tokenUserId !== $requesterUserId) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'Cannot query reservations for other users (token user_id must match requester_user_id)'
                ], 403);
            }
            
            $query->where('reservations.requester_user_id', $requesterUserId);
        }
        
        // Store scope: Filter by provider_tenant_id (WP-NEXT: auth + HOS membership required)
        if ($request->has('provider_tenant_id')) {
            $providerTenantId = $request->input('provider_tenant_id');
            $membershipClient = new \App\Core\MembershipClient();
            $err = requireStoreScopeAuthz($request, $membershipClient, $providerTenantId);
            if ($err !== null) {
                return $err;
            }
            $query->where('reservations.provider_tenant_id', $providerTenantId);
        }
        
        // Pagination (WP-12.1: per_page default 20, max 50)
        $page = max(1, (int)$request->input('page', 1));
        $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
        $offset = ($page - 1) * $perPage;
        
        // Get total count before pagination
        $total = $query->count();
        
        $reservations = $query->select('reservations.*', 'listings.title as listing_title')
            ->orderBy('reservations.created_at', 'desc')
            ->offset($offset)
            ->limit($perPage)
            ->get()
            ->map(function ($reservation) {
                return [
                    'id' => $reservation->id,
                    'listing_id' => $reservation->listing_id,
                    'listing_title' => $reservation->listing_title ?? null,
                    'offer_id' => $reservation->offer_id ?? null,
                    'pricing_source' => $reservation->pricing_source ?? null,
                    'price_amount' => $reservation->price_amount ?? null,
                    'price_currency' => $reservation->price_currency ?? null,
                    'billing_model' => $reservation->billing_model ?? null,
                    'totals' => $reservation->totals_json ? json_decode($reservation->totals_json, true) : null,
                    'provider_tenant_id' => $reservation->provider_tenant_id,
                    'requester_user_id' => $reservation->requester_user_id,
                    'slot_start' => $reservation->slot_start,
                    'slot_end' => $reservation->slot_end,
                    'party_size' => $reservation->party_size,
                    'status' => $reservation->status,
                    'created_at' => $reservation->created_at,
                    'updated_at' => $reservation->updated_at
                ];
            });
        
        // WP-12.1: Response envelope format {data, meta}
        return response()->json([
            'data' => $reservations,
            'meta' => [
                'total' => $total,
                'page' => $page,
                'per_page' => $perPage,
                'total_pages' => (int) ceil($total / $perPage)
            ]
        ]);
    } catch (\Exception $e) {
        \Log::error('GET /v1/reservations error: ' . $e->getMessage(), ['exception' => $e]);
        return response()->json([
            'error' => 'INTERNAL_ERROR',
            'message' => 'Server error occurred while processing request'
        ], 500);
    }
});

// WP-NEXT: Transactions getById â€” GET /v1/orders/{id} (read-only, personal or store scope)
Route::middleware('auth.ctx')->get('/v1/orders/{id}', function ($id, \Illuminate\Http\Request $request) {
    if (!\Illuminate\Support\Str::isUuid($id)) {
        return response()->json(['error' => 'VALIDATION_ERROR', 'message' => 'Invalid id format'], 422);
    }
    if (!$request->has('buyer_user_id') && !$request->has('seller_tenant_id')) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'Either buyer_user_id or seller_tenant_id parameter is required'
        ], 422);
    }
    $query = DB::table('orders')
        ->leftJoin('listings', 'orders.listing_id', '=', 'listings.id')
        ->where('orders.id', $id);
    if ($request->has('buyer_user_id')) {
        $tokenUserId = $request->attributes->get('requester_user_id');
        $buyerUserId = $request->input('buyer_user_id');
        if (!$tokenUserId) {
            return response()->json(['error' => 'AUTH_REQUIRED', 'message' => 'Authorization: Bearer token is required for personal scope queries'], 401);
        }
        if ($tokenUserId !== $buyerUserId) {
            return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Cannot query orders for other users (token user_id must match buyer_user_id)'], 403);
        }
        $query->where('orders.buyer_user_id', $buyerUserId);
    }
    if ($request->has('seller_tenant_id')) {
        $sellerTenantId = $request->input('seller_tenant_id');
        $tenantIdHeader = $request->header('X-Active-Tenant-Id');
        if (!$tenantIdHeader) {
            return response()->json(['error' => 'VALIDATION_ERROR', 'message' => 'X-Active-Tenant-Id header is required for store scope'], 400);
        }
        $membershipClient = new \App\Core\MembershipClient();
        if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
            return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'], 403);
        }
        if ($tenantIdHeader !== $sellerTenantId) {
            return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'X-Active-Tenant-Id header must match seller_tenant_id parameter'], 403);
        }
        $query->where('orders.seller_tenant_id', $sellerTenantId);
    }
    $order = $query->select('orders.*', 'listings.title as listing_title')->first();
    if (!$order) {
        return response()->json(['error' => 'order_not_found', 'message' => "Order with id {$id} not found"], 404);
    }
    $mapped = [
        'id' => $order->id,
        'listing_id' => $order->listing_id,
        'listing_title' => $order->listing_title ?? null,
        'buyer_user_id' => $order->buyer_user_id,
        'seller_tenant_id' => $order->seller_tenant_id,
        'quantity' => $order->quantity,
        'status' => $order->status,
        'totals' => $order->totals_json ? json_decode($order->totals_json, true) : null,
        'created_at' => $order->created_at,
        'updated_at' => $order->updated_at
    ];
    return response()->json(['data' => $mapped]);
});

// WP-NEXT: Transactions getById â€” GET /v1/rentals/{id} (read-only, personal or store scope)
Route::middleware('auth.ctx')->get('/v1/rentals/{id}', function ($id, \Illuminate\Http\Request $request) {
    if (!\Illuminate\Support\Str::isUuid($id)) {
        return response()->json(['error' => 'VALIDATION_ERROR', 'message' => 'Invalid id format'], 422);
    }
    if (!$request->has('renter_user_id') && !$request->has('provider_tenant_id')) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'Either renter_user_id or provider_tenant_id parameter is required'
        ], 422);
    }
    $query = DB::table('rentals')
        ->leftJoin('listings', 'rentals.listing_id', '=', 'listings.id')
        ->where('rentals.id', $id);
    if ($request->has('renter_user_id')) {
        $tokenUserId = $request->attributes->get('requester_user_id');
        $renterUserId = $request->input('renter_user_id');
        if (!$tokenUserId) {
            return response()->json(['error' => 'AUTH_REQUIRED', 'message' => 'Authorization: Bearer token is required for personal scope queries'], 401);
        }
        if ($tokenUserId !== $renterUserId) {
            return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Cannot query rentals for other users (token user_id must match renter_user_id)'], 403);
        }
        $query->where('rentals.renter_user_id', $renterUserId);
    }
    if ($request->has('provider_tenant_id')) {
        $providerTenantId = $request->input('provider_tenant_id');
        $membershipClient = new \App\Core\MembershipClient();
        $err = requireStoreScopeAuthz($request, $membershipClient, $providerTenantId);
        if ($err !== null) {
            return $err;
        }
        $query->where('rentals.provider_tenant_id', $providerTenantId);
    }
    $rental = $query->select('rentals.*', 'listings.title as listing_title')->first();
    if (!$rental) {
        return response()->json(['error' => 'rental_not_found', 'message' => "Rental with id {$id} not found"], 404);
    }
    $mapped = [
        'id' => $rental->id,
        'listing_id' => $rental->listing_id,
        'listing_title' => $rental->listing_title ?? null,
        'renter_user_id' => $rental->renter_user_id,
        'provider_tenant_id' => $rental->provider_tenant_id,
        'pricing_source' => $rental->pricing_source ?? null,
        'price_amount' => $rental->price_amount ?? null,
        'price_currency' => $rental->price_currency ?? null,
        'billing_model' => $rental->billing_model ?? null,
        'totals' => $rental->totals_json ? json_decode($rental->totals_json, true) : null,
        'start_at' => $rental->start_at,
        'end_at' => $rental->end_at,
        'status' => $rental->status,
        'created_at' => $rental->created_at,
        'updated_at' => $rental->updated_at
    ];
    return response()->json(['data' => $mapped]);
});

// WP-NEXT: Transactions getById â€” GET /v1/reservations/{id} (read-only, personal or store scope)
Route::middleware('auth.ctx')->get('/v1/reservations/{id}', function ($id, \Illuminate\Http\Request $request) {
    if (!\Illuminate\Support\Str::isUuid($id)) {
        return response()->json(['error' => 'VALIDATION_ERROR', 'message' => 'Invalid id format'], 422);
    }
    if (!$request->has('requester_user_id') && !$request->has('provider_tenant_id')) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'Either requester_user_id or provider_tenant_id parameter is required'
        ], 422);
    }
    $query = DB::table('reservations')
        ->leftJoin('listings', 'reservations.listing_id', '=', 'listings.id')
        ->where('reservations.id', $id);
    if ($request->has('requester_user_id')) {
        $tokenUserId = $request->attributes->get('requester_user_id');
        $requesterUserId = $request->input('requester_user_id');
        if (!$tokenUserId) {
            return response()->json(['error' => 'AUTH_REQUIRED', 'message' => 'Authorization: Bearer token is required for personal scope queries'], 401);
        }
        if ($tokenUserId !== $requesterUserId) {
            return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Cannot query reservations for other users (token user_id must match requester_user_id)'], 403);
        }
        $query->where('reservations.requester_user_id', $requesterUserId);
    }
    if ($request->has('provider_tenant_id')) {
        $providerTenantId = $request->input('provider_tenant_id');
        $membershipClient = new \App\Core\MembershipClient();
        $err = requireStoreScopeAuthz($request, $membershipClient, $providerTenantId);
        if ($err !== null) {
            return $err;
        }
        $query->where('reservations.provider_tenant_id', $providerTenantId);
    }
    $reservation = $query->select('reservations.*', 'listings.title as listing_title')->first();
    if (!$reservation) {
        return response()->json(['error' => 'reservation_not_found', 'message' => "Reservation with id {$id} not found"], 404);
    }
    $mapped = [
        'id' => $reservation->id,
        'listing_id' => $reservation->listing_id,
        'listing_title' => $reservation->listing_title ?? null,
        'offer_id' => $reservation->offer_id ?? null,
        'pricing_source' => $reservation->pricing_source ?? null,
        'price_amount' => $reservation->price_amount ?? null,
        'price_currency' => $reservation->price_currency ?? null,
        'billing_model' => $reservation->billing_model ?? null,
        'totals' => $reservation->totals_json ? json_decode($reservation->totals_json, true) : null,
        'provider_tenant_id' => $reservation->provider_tenant_id,
        'requester_user_id' => $reservation->requester_user_id,
        'slot_start' => $reservation->slot_start,
        'slot_end' => $reservation->slot_end,
        'party_size' => $reservation->party_size,
        'status' => $reservation->status,
        'created_at' => $reservation->created_at,
        'updated_at' => $reservation->updated_at
    ];
    return response()->json(['data' => $mapped]);
});


