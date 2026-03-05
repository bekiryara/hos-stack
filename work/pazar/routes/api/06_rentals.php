<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// Rental Spine Endpoints (WP-7)
// POST /v1/rentals - Create rental request
// WP-8: PERSONAL persona requires Authorization header (persona.scope:personal)
// WP-29: Auth required via auth.any middleware
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':personal', 'auth.any', 'auth.ctx'])->post('/v1/rentals', function (\Illuminate\Http\Request $request) {
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
        'start_at' => 'required|date',
        'end_at' => 'required|date|after:start_at'
    ]);
    
    // Get listing
    $listing = DB::table('listings')->where('id', $validated['listing_id'])->first();
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$validated['listing_id']} not found"
        ], 404);
    }
    
    // Check listing is published
    if ($listing->status !== 'published') {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => "Listing must be published to create rentals. Current status: {$listing->status}"
        ], 422);
    }

    // Policy-derived service primitives (deterministic).
    // Rental flow supports date_range model; legacy 'none' is allowed for backward compatibility.
    $intent = pazar_category_intent_schema((int) $listing->category_id);
    $serviceTimeModel = isset($intent['service_time_model']) ? (string) $intent['service_time_model'] : 'none';
    if (!in_array($serviceTimeModel, ['date_range', 'none'], true)) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => "Rental flow is not allowed for service_time_model '{$serviceTimeModel}'"
        ], 422);
    }

    // Offer requirement policy:
    // Rental v1 does not support selecting offer_id in create payload.
    $offerRequirement = isset($intent['offer_requirement']) ? (string) $intent['offer_requirement'] : 'no_offer';
    if ($offerRequirement === 'required_offer') {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'rental create requires offer selection, but offer-based rental is not supported in v1'
        ], 422);
    }

    try {
        $pricing = pazar_resolve_transaction_pricing($listing, null);
    } catch (\InvalidArgumentException $e) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => $e->getMessage()
        ], 422);
    }
    
    // Idempotency check (MUST be before overlap check to avoid false conflicts)
    // WP-13: Get requester_user_id from request attributes (set by AuthContext middleware)
    $scopeType = 'user';
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
    
    // Check date overlap: requested/accepted/active rentals that overlap same listing
    $startAt = new \DateTime($validated['start_at']);
    $endAt = new \DateTime($validated['end_at']);
    
    $overlapping = DB::table('rentals')
        ->where('listing_id', $validated['listing_id'])
        ->whereIn('status', ['requested', 'accepted', 'active'])
        ->where(function ($query) use ($startAt, $endAt) {
            $query->where(function ($q) use ($startAt, $endAt) {
                // Rental starts before our end and ends after our start
                $q->where('start_at', '<', $endAt->format('Y-m-d H:i:s'))
                  ->where('end_at', '>', $startAt->format('Y-m-d H:i:s'));
            });
        })
        ->first();
    
    if ($overlapping) {
        return response()->json([
            'error' => 'CONFLICT',
            'message' => 'Rental period overlaps with existing rental',
            'conflicting_rental_id' => $overlapping->id
        ], 409);
    }
    
    // Create rental
    // WP-13: Get requester_user_id from request attributes (set by AuthContext middleware)
    $rentalId = \Illuminate\Support\Str::uuid()->toString();
    $providerTenantId = $listing->tenant_id;
    $renterUserId = $request->attributes->get('requester_user_id');
    
    if (!$renterUserId) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'Authorization token required (requester_user_id missing)'
        ], 422);
    }
    
    DB::table('rentals')->insert([
        'id' => $rentalId,
        'listing_id' => $validated['listing_id'],
        'renter_user_id' => $renterUserId,
        'provider_tenant_id' => $providerTenantId,
        'pricing_source' => $pricing['pricing_source'],
        'price_amount' => $pricing['price_amount'],
        'price_currency' => $pricing['price_currency'],
        'billing_model' => $pricing['billing_model'],
        'start_at' => $startAt->format('Y-m-d H:i:s'),
        'end_at' => $endAt->format('Y-m-d H:i:s'),
        'status' => 'requested',
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    $response = [
        'id' => $rentalId,
        'listing_id' => $validated['listing_id'],
        'renter_user_id' => $renterUserId,
        'provider_tenant_id' => $providerTenantId,
        'pricing_source' => $pricing['pricing_source'],
        'price_amount' => $pricing['price_amount'],
        'price_currency' => $pricing['price_currency'],
        'billing_model' => $pricing['billing_model'],
        'start_at' => $startAt->format('Y-m-d\TH:i:s\Z'),
        'end_at' => $endAt->format('Y-m-d\TH:i:s\Z'),
        'status' => 'requested',
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
    
    return response()->json($response, 201);
});

// POST /v1/rentals/{id}/accept - Accept rental
// WP-8: STORE persona requires X-Active-Tenant-Id header (persona.scope:store)
// WP-26: Tenant scope enforced via tenant.scope middleware
// WP-29: Auth required via auth.any middleware
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':store', 'auth.any', 'auth.ctx', 'tenant.scope', 'tenant.membership_strict'])->post('/v1/rentals/{id}/accept', function ($id, \Illuminate\Http\Request $request) {
    // WP-26: tenant_id is set by TenantScope middleware
    $tenantId = $request->attributes->get('tenant_id');
    
    // Find rental
    $rental = DB::table('rentals')->where('id', $id)->first();
    if (!$rental) {
        return response()->json([
            'error' => 'rental_not_found',
            'message' => "Rental with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership (FORBIDDEN_SCOPE)
    if ($rental->provider_tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Only the listing owner can accept this rental'
        ], 403);
    }
    
    // Check status is requested (state transition validation)
    if ($rental->status !== 'requested') {
        return response()->json([
            'error' => 'INVALID_STATE',
            'message' => "Rental must be in 'requested' status to accept. Current status: {$rental->status}"
        ], 422);
    }
    
    // Update status to accepted (atomic operation)
    // NOTE: Accept does NOT perform overlap checks - only create does
    // Accept only validates: tenant ownership, state transition (requested -> accepted)
    $updated = DB::table('rentals')
        ->where('id', $id)
        ->where('status', 'requested') // Atomic: only update if still requested
        ->update([
            'status' => 'accepted',
            'updated_at' => now()
        ]);
    
    // Verify update succeeded (race condition check)
    if ($updated === 0) {
        // Status changed between check and update (race condition or idempotency)
        $current = DB::table('rentals')->where('id', $id)->first();
        if ($current && $current->status === 'accepted') {
            // Already accepted (idempotent accept)
            $rental = $current;
        } else {
            return response()->json([
                'error' => 'INTERNAL_ERROR',
                'message' => 'Failed to update rental status'
            ], 500);
        }
    } else {
        // Reload updated rental
        $rental = DB::table('rentals')->where('id', $id)->first();
    }
    
    return response()->json([
        'id' => $rental->id,
        'listing_id' => $rental->listing_id,
        'renter_user_id' => $rental->renter_user_id,
        'provider_tenant_id' => $rental->provider_tenant_id,
        'pricing_source' => $rental->pricing_source ?? null,
        'price_amount' => $rental->price_amount ?? null,
        'price_currency' => $rental->price_currency ?? null,
        'billing_model' => $rental->billing_model ?? null,
        'start_at' => $rental->start_at,
        'end_at' => $rental->end_at,
        'status' => $rental->status,
        'updated_at' => $rental->updated_at
    ]);
});

// WP-NEXT: Transaction Decisions v1 — POST /v1/rentals/{id}/reject
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':store', 'auth.any', 'auth.ctx', 'tenant.scope', 'tenant.membership_strict'])->post('/v1/rentals/{id}/reject', function ($id, \Illuminate\Http\Request $request) {
    $tenantId = $request->attributes->get('tenant_id');
    $rental = DB::table('rentals')->where('id', $id)->first();
    if (!$rental) {
        return response()->json(['error' => 'rental_not_found', 'message' => "Rental with id {$id} not found"], 404);
    }
    if ($rental->provider_tenant_id !== $tenantId) {
        return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Only the provider can reject this rental'], 403);
    }
    if ($rental->status !== 'requested') {
        return response()->json(['error' => 'INVALID_STATE', 'message' => "Rental must be in 'requested' status to reject. Current status: {$rental->status}"], 422);
    }
    $updated = DB::table('rentals')->where('id', $id)->where('status', 'requested')->update(['status' => 'rejected', 'updated_at' => now()]);
    if ($updated === 0) {
        $cur = DB::table('rentals')->where('id', $id)->first();
        if ($cur && $cur->status === 'rejected') {
            $rental = $cur;
        } else {
            return response()->json(['error' => 'VALIDATION_ERROR', 'message' => 'Rental status changed during update'], 422);
        }
    } else {
        $rental = DB::table('rentals')->where('id', $id)->first();
    }
    return response()->json([
        'id' => $rental->id,
        'listing_id' => $rental->listing_id,
        'renter_user_id' => $rental->renter_user_id,
        'provider_tenant_id' => $rental->provider_tenant_id,
        'pricing_source' => $rental->pricing_source ?? null,
        'price_amount' => $rental->price_amount ?? null,
        'price_currency' => $rental->price_currency ?? null,
        'billing_model' => $rental->billing_model ?? null,
        'start_at' => $rental->start_at,
        'end_at' => $rental->end_at,
        'status' => $rental->status,
        'updated_at' => $rental->updated_at
    ]);
});

// WP-NEXT: Transaction Lifecycle v1 — POST /v1/rentals/{id}/transition
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':store', 'auth.any', 'auth.ctx', 'tenant.scope'])->post('/v1/rentals/{id}/transition', function ($id, \Illuminate\Http\Request $request) {
    $validated = $request->validate(['action' => 'required|string|in:approve,reject,cancel,complete']);
    $action = $validated['action'];
    $tenantId = $request->attributes->get('tenant_id');

    $rental = DB::table('rentals')->where('id', $id)->first();
    if (!$rental) {
        return response()->json(['error' => 'rental_not_found', 'message' => "Rental with id {$id} not found"], 404);
    }
    if ($rental->provider_tenant_id !== $tenantId) {
        return response()->json(['error' => 'FORBIDDEN_SCOPE', 'message' => 'Only the provider can transition this rental'], 403);
    }

    $allowlist = [
        'requested' => ['approve' => 'accepted', 'reject' => 'rejected', 'cancel' => 'cancelled'],
        'accepted' => ['complete' => 'completed'],
    ];
    $current = $rental->status;
    $allowed = $allowlist[$current] ?? [];
    if (!isset($allowed[$action])) {
        return response()->json([
            'error' => 'INVALID_TRANSITION',
            'message' => "Action '{$action}' not allowed from status '{$current}'",
            'allowed' => array_keys($allowed),
        ], 422);
    }
    $newStatus = $allowed[$action];

    $updated = DB::table('rentals')->where('id', $id)->where('status', $current)->update([
        'status' => $newStatus,
        'updated_at' => now(),
    ]);
    if ($updated === 0) {
        $cur = DB::table('rentals')->where('id', $id)->first();
        return response()->json([
            'error' => 'INVALID_TRANSITION',
            'message' => 'Status changed during update',
            'allowed' => array_keys($allowlist[$cur->status] ?? []),
        ], 422);
    }
    \Illuminate\Support\Facades\Log::info('rental.transition', ['rental_id' => $id, 'action' => $action, 'from' => $current, 'to' => $newStatus]);
    $row = DB::table('rentals')->where('id', $id)->first();
    return response()->json(['id' => $row->id, 'status' => $row->status, 'updated_at' => $row->updated_at], 200);
});
