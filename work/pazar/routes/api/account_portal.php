<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

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
        
        $query = DB::table('orders');
        
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
            
            $query->where('buyer_user_id', $buyerUserId);
        }
        
        // Store scope: Filter by seller_tenant_id (requires X-Active-Tenant-Id)
        if ($request->has('seller_tenant_id')) {
            $sellerTenantId = $request->input('seller_tenant_id');
            $tenantIdHeader = $request->header('X-Active-Tenant-Id');
            
            // WP-12.1: Store scope requires X-Active-Tenant-Id header
            if (!$tenantIdHeader) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'X-Active-Tenant-Id header is required for store scope'
                ], 400);
            }
            
            // WP-12.1: Validate tenant_id format (UUID format check)
            $membershipClient = new \App\Core\MembershipClient();
            if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
                ], 403);
            }
            
            // Verify X-Active-Tenant-Id matches seller_tenant_id for security
            if ($tenantIdHeader !== $sellerTenantId) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'X-Active-Tenant-Id header must match seller_tenant_id parameter'
                ], 403);
            }
            
            $query->where('seller_tenant_id', $sellerTenantId);
        }
        
        // Pagination (WP-12.1: per_page default 20, max 50)
        $page = max(1, (int)$request->input('page', 1));
        $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
        $offset = ($page - 1) * $perPage;
        
        // Get total count before pagination
        $total = $query->count();
        
        $orders = $query->orderBy('created_at', 'desc')
            ->offset($offset)
            ->limit($perPage)
            ->get()
            ->map(function ($order) {
                return [
                    'id' => $order->id,
                    'listing_id' => $order->listing_id,
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
        
        $query = DB::table('rentals');
        
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
            
            $query->where('renter_user_id', $renterUserId);
        }
        
        // Store scope: Filter by provider_tenant_id (requires X-Active-Tenant-Id)
        if ($request->has('provider_tenant_id')) {
            $providerTenantId = $request->input('provider_tenant_id');
            $tenantIdHeader = $request->header('X-Active-Tenant-Id');
            
            // WP-12.1: Store scope requires X-Active-Tenant-Id header
            if (!$tenantIdHeader) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'X-Active-Tenant-Id header is required for store scope'
                ], 400);
            }
            
            // WP-12.1: Validate tenant_id format (UUID format check)
            $membershipClient = new \App\Core\MembershipClient();
            if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
                ], 403);
            }
            
            // Verify X-Active-Tenant-Id matches provider_tenant_id for security
            if ($tenantIdHeader !== $providerTenantId) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'X-Active-Tenant-Id header must match provider_tenant_id parameter'
                ], 403);
            }
            
            $query->where('provider_tenant_id', $providerTenantId);
        }
        
        // Pagination (WP-12.1: per_page default 20, max 50)
        $page = max(1, (int)$request->input('page', 1));
        $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
        $offset = ($page - 1) * $perPage;
        
        // Get total count before pagination
        $total = $query->count();
        
        $rentals = $query->orderBy('created_at', 'desc')
            ->offset($offset)
            ->limit($perPage)
            ->get()
            ->map(function ($rental) {
                return [
                    'id' => $rental->id,
                    'listing_id' => $rental->listing_id,
                    'renter_user_id' => $rental->renter_user_id,
                    'provider_tenant_id' => $rental->provider_tenant_id,
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
        
        $query = DB::table('reservations');
        
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
            
            $query->where('requester_user_id', $requesterUserId);
        }
        
        // Store scope: Filter by provider_tenant_id (requires X-Active-Tenant-Id)
        if ($request->has('provider_tenant_id')) {
            $providerTenantId = $request->input('provider_tenant_id');
            $tenantIdHeader = $request->header('X-Active-Tenant-Id');
            
            // WP-12.1: Store scope requires X-Active-Tenant-Id header
            if (!$tenantIdHeader) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'X-Active-Tenant-Id header is required for store scope'
                ], 400);
            }
            
            // WP-12.1: Validate tenant_id format (UUID format check)
            $membershipClient = new \App\Core\MembershipClient();
            if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
                ], 403);
            }
            
            // Verify X-Active-Tenant-Id matches provider_tenant_id for security
            if ($tenantIdHeader !== $providerTenantId) {
                return response()->json([
                    'error' => 'FORBIDDEN_SCOPE',
                    'message' => 'X-Active-Tenant-Id header must match provider_tenant_id parameter'
                ], 403);
            }
            
            $query->where('provider_tenant_id', $providerTenantId);
        }
        
        // Pagination (WP-12.1: per_page default 20, max 50)
        $page = max(1, (int)$request->input('page', 1));
        $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
        $offset = ($page - 1) * $perPage;
        
        // Get total count before pagination
        $total = $query->count();
        
        $reservations = $query->orderBy('created_at', 'desc')
            ->offset($offset)
            ->limit($perPage)
            ->get()
            ->map(function ($reservation) {
                return [
                    'id' => $reservation->id,
                    'listing_id' => $reservation->listing_id,
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

