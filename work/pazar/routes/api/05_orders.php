<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// Order Spine Endpoints (WP-6)
// POST /v1/orders - Create order
// WP-8: PERSONAL persona requires Authorization header (persona.scope:personal)
// WP-29: Auth required via auth.any middleware
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':personal', 'auth.any', 'auth.ctx'])->post('/v1/orders', function (\Illuminate\Http\Request $request) {
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
    $orderId = \Illuminate\Support\Str::uuid()->toString();
    $sellerTenantId = $listing->tenant_id;
    $buyerUserId = $request->attributes->get('requester_user_id');
    
    // Calculate totals from listing price
    $attrs = json_decode($listing->attributes_json ?? '{}', true) ?: [];
    $cardDisplay = pazar_card_display_for_category((int) $listing->category_id);
    $priceField = $cardDisplay['price_field'] ?? null;
    $unitPrice = ($priceField && isset($attrs[$priceField]) && is_numeric($attrs[$priceField]))
        ? (float) $attrs[$priceField]
        : null;
    $currency = $cardDisplay['currency'] ?? 'TRY';

    $totals = null;
    if ($unitPrice !== null) {
        $totals = [
            'unit_price' => $unitPrice,
            'quantity' => $quantity,
            'subtotal' => round($unitPrice * $quantity, 2),
            'currency' => $currency,
        ];
    }
    
    DB::table('orders')->insert([
        'id' => $orderId,
        'listing_id' => $validated['listing_id'],
        'seller_tenant_id' => $sellerTenantId,
        'buyer_user_id' => $buyerUserId,
        'quantity' => $quantity,
        'status' => 'placed',
        'totals_json' => $totals ? json_encode($totals) : null,
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
        'totals' => $totals,
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

// WP-NEXT: Transaction Decisions v1 — POST /v1/orders/{id}/accept
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':store', 'auth.any', 'auth.ctx', 'tenant.scope', 'tenant.membership_strict'])->post('/v1/orders/{id}/accept', function ($id, \Illuminate\Http\Request $request) {
    $tenantId = $request->attributes->get('tenant_id');
    $order = DB::table('orders')->where('id', $id)->first();
    if (!$order) {
        return response()->json(['error' => 'order_not_found', 'message' => "Order with id {$id} not found"], 404);
    }
    if ($order->seller_tenant_id !== $tenantId) {
        return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Only the seller can accept this order'], 403);
    }
    if ($order->status !== 'placed') {
        return response()->json(['error' => 'INVALID_STATE', 'message' => "Order must be in 'placed' status to accept. Current status: {$order->status}"], 422);
    }
    $updated = DB::table('orders')->where('id', $id)->where('status', 'placed')->update(['status' => 'accepted', 'updated_at' => now()]);
    if ($updated === 0) {
        $cur = DB::table('orders')->where('id', $id)->first();
        if ($cur && $cur->status === 'accepted') {
            $order = $cur;
        } else {
            return response()->json(['error' => 'VALIDATION_ERROR', 'message' => 'Order status changed during update'], 422);
        }
    } else {
        $order = DB::table('orders')->where('id', $id)->first();
    }
    return response()->json([
        'id' => $order->id,
        'seller_tenant_id' => $order->seller_tenant_id,
        'listing_id' => $order->listing_id,
        'status' => $order->status,
        'updated_at' => $order->updated_at
    ]);
});

// WP-NEXT: Transaction Decisions v1 — POST /v1/orders/{id}/reject
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':store', 'auth.any', 'auth.ctx', 'tenant.scope', 'tenant.membership_strict'])->post('/v1/orders/{id}/reject', function ($id, \Illuminate\Http\Request $request) {
    $tenantId = $request->attributes->get('tenant_id');
    $order = DB::table('orders')->where('id', $id)->first();
    if (!$order) {
        return response()->json(['error' => 'order_not_found', 'message' => "Order with id {$id} not found"], 404);
    }
    if ($order->seller_tenant_id !== $tenantId) {
        return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Only the seller can reject this order'], 403);
    }
    if ($order->status !== 'placed') {
        return response()->json(['error' => 'INVALID_STATE', 'message' => "Order must be in 'placed' status to reject. Current status: {$order->status}"], 422);
    }
    $updated = DB::table('orders')->where('id', $id)->where('status', 'placed')->update(['status' => 'rejected', 'updated_at' => now()]);
    if ($updated === 0) {
        $cur = DB::table('orders')->where('id', $id)->first();
        if ($cur && $cur->status === 'rejected') {
            $order = $cur;
        } else {
            return response()->json(['error' => 'VALIDATION_ERROR', 'message' => 'Order status changed during update'], 422);
        }
    } else {
        $order = DB::table('orders')->where('id', $id)->first();
    }
    return response()->json([
        'id' => $order->id,
        'seller_tenant_id' => $order->seller_tenant_id,
        'listing_id' => $order->listing_id,
        'status' => $order->status,
        'updated_at' => $order->updated_at
    ]);
});

// WP-NEXT: Transaction Lifecycle v1 — POST /v1/orders/{id}/transition
// Store scope: seller can approve/reject/cancel/complete. Allowlist: placed->approved->completed, placed->rejected, placed->cancelled.
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':store', 'auth.any', 'auth.ctx', 'tenant.scope'])->post('/v1/orders/{id}/transition', function ($id, \Illuminate\Http\Request $request) {
    $validated = $request->validate(['action' => 'required|string|in:approve,reject,cancel,complete']);
    $action = $validated['action'];
    $tenantId = $request->attributes->get('tenant_id');

    $order = DB::table('orders')->where('id', $id)->first();
    if (!$order) {
        return response()->json(['error' => 'order_not_found', 'message' => "Order with id {$id} not found"], 404);
    }
    if ($order->seller_tenant_id !== $tenantId) {
        return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Only the seller can transition this order'], 403);
    }

    $allowlist = [
        'placed' => ['approve' => 'approved', 'reject' => 'rejected', 'cancel' => 'cancelled'],
        'approved' => ['complete' => 'completed'],
    ];
    $current = $order->status;
    $allowed = $allowlist[$current] ?? [];
    if (!isset($allowed[$action])) {
        return response()->json([
            'error' => 'INVALID_TRANSITION',
            'message' => "Action '{$action}' not allowed from status '{$current}'",
            'allowed' => array_keys($allowed),
        ], 422);
    }
    $newStatus = $allowed[$action];

    $updated = DB::table('orders')->where('id', $id)->where('status', $current)->update([
        'status' => $newStatus,
        'updated_at' => now(),
    ]);
    if ($updated === 0) {
        $cur = DB::table('orders')->where('id', $id)->first();
        return response()->json([
            'error' => 'INVALID_TRANSITION',
            'message' => 'Status changed during update',
            'allowed' => array_keys($allowlist[$cur->status] ?? []),
        ], 422);
    }
    \Illuminate\Support\Facades\Log::info('order.transition', ['order_id' => $id, 'action' => $action, 'from' => $current, 'to' => $newStatus]);
    $row = DB::table('orders')->where('id', $id)->first();
    return response()->json(['id' => $row->id, 'status' => $row->status, 'updated_at' => $row->updated_at], 200);
});

