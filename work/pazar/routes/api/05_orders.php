<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// Order Spine Endpoints (WP-6)
// POST /v1/orders - Create order
// WP-29: Auth required via auth.any middleware
Route::middleware(['auth.any', 'auth.ctx'])->post('/v1/orders', function (\Illuminate\Http\Request $request) {
    // WP-13: AuthContext middleware handles JWT verification and sets requester_user_id
    
    // Require Idempotency-Key header
    $idempotencyKey = $request->header('Idempotency-Key');
    if (!$idempotencyKey) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'Idempotency-Key header is required'
        ], 400);
    }
    
    // Validate required fields
    $validated = $request->validate([
        'listing_id' => 'required|uuid',
        'quantity' => 'integer|min:1'
    ]);
    
    // Default quantity to 1 if not provided
    $quantity = $validated['quantity'] ?? 1;
    
    // Get listing
    $listing = DB::table('listings')->where('id', $validated['listing_id'])->first();
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$validated['listing_id']} not found"
        ], 404);
    }
    
    // Check listing is published (domain invariant)
    if ($listing->status !== 'published') {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => "Listing must be published to create orders. Current status: {$listing->status}"
        ], 422);
    }
    
    // Idempotency check (MUST be before order creation)
    // WP-13: Get requester_user_id from request attributes (set by AuthContext middleware)
    $scopeType = 'user'; // Personal scope for buyer
    $scopeId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
    $requestHash = hash('sha256', json_encode($validated));
    
    $existingIdempotency = DB::table('idempotency_keys')
        ->where('scope_type', $scopeType)
        ->where('scope_id', $scopeId)
        ->where('key', $idempotencyKey)
        ->where('request_hash', $requestHash)
        ->where('expires_at', '>', now())
        ->first();
    
    if ($existingIdempotency) {
        // Return cached response (idempotency replay)
        $cachedResponse = json_decode($existingIdempotency->response_json, true);
        return response()->json($cachedResponse, 200);
    }
    
    // Create order
    // WP-13: Get requester_user_id from request attributes (set by AuthContext middleware)
    $orderId = \Illuminate\Support\Str::uuid()->toString();
    $sellerTenantId = $listing->tenant_id;
    $buyerUserId = $request->attributes->get('requester_user_id');
    
    DB::table('orders')->insert([
        'id' => $orderId,
        'listing_id' => $validated['listing_id'],
        'seller_tenant_id' => $sellerTenantId,
        'buyer_user_id' => $buyerUserId,
        'quantity' => $quantity,
        'status' => 'placed',
        'totals_json' => null, // Placeholder for future pricing logic
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    $response = [
        'id' => $orderId,
        'listing_id' => $validated['listing_id'],
        'buyer_user_id' => $buyerUserId,
        'seller_tenant_id' => $sellerTenantId,
        'quantity' => $quantity,
        'status' => 'placed',
        'totals_json' => null,
        'created_at' => now()->toISOString()
    ];
    
    // Store idempotency key (expires in 24 hours)
    DB::table('idempotency_keys')->insert([
        'scope_type' => $scopeType,
        'scope_id' => $scopeId,
        'key' => $idempotencyKey,
        'request_hash' => $requestHash,
        'response_json' => json_encode($response),
        'created_at' => now(),
        'expires_at' => now()->addHours(24)
    ]);
    
    // Create messaging thread for order (context-only integration, WP-5)
    // Non-fatal: if messaging service is unavailable, order still succeeds
    try {
        $messagingClient = new \App\Messaging\MessagingClient();
        $participants = [];
        
        if ($buyerUserId) {
            $participants[] = ['type' => 'user', 'id' => $buyerUserId];
        }
        if ($sellerTenantId) {
            $participants[] = ['type' => 'tenant', 'id' => $sellerTenantId];
        }
        
        if (!empty($participants)) {
            $messagingClient->upsertThread('order', $orderId, $participants);
        }
    } catch (\Exception $e) {
        // Non-fatal: log but do not fail order creation
        \Illuminate\Support\Facades\Log::warning('messaging.thread_creation.failed', [
            'order_id' => $orderId,
            'error' => $e->getMessage()
        ]);
    }
    
    return response()->json($response, 201);
});

