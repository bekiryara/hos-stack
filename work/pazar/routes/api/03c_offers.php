<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// WP-9: Offers/Pricing Spine Endpoints

// POST /v1/listings/{id}/offers - Create offer
Route::post('/v1/listings/{id}/offers', function ($id, \Illuminate\Http\Request $request) {
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
    $membershipClient = new \App\Core\MembershipClient();
    $userId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
    $authToken = $request->header('Authorization');
    
    // Validate tenant_id format
    if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
        ], 403);
    }
    
    // Validate membership
    if (!$membershipClient->validateMembership($userId, $tenantIdHeader, $authToken)) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Invalid membership or tenant access denied'
        ], 403);
    }
    
    $tenantId = $tenantIdHeader;
    
    // Require Idempotency-Key header
    $idempotencyKey = $request->header('Idempotency-Key');
    if (!$idempotencyKey) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'Idempotency-Key header is required'
        ], 400);
    }
    
    // Find listing
    $listing = DB::table('listings')->where('id', $id)->first();
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership (FORBIDDEN_SCOPE)
    if ($listing->tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'X-Active-Tenant-Id header must match listing tenant_id'
        ], 403);
    }
    
    // Validate required fields
    $validated = $request->validate([
        'code' => 'required|string|max:100',
        'name' => 'required|string|max:255',
        'price_amount' => 'required|integer|min:0',
        'price_currency' => 'nullable|string|size:3',
        'billing_model' => 'required|string|in:one_time,per_hour,per_day,per_person',
        'attributes' => 'nullable|array'
    ]);
    
    // Idempotency check (MUST be before offer creation and code uniqueness check)
    $scopeType = 'tenant'; // Store scope
    $scopeId = $tenantId;
    // Include listing_id in request hash for idempotency (same code can exist in different listings)
    $requestData = array_merge($validated, ['listing_id' => $id]);
    $requestHash = hash('sha256', json_encode($requestData));
    
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
    
    // Check code uniqueness within listing (AFTER idempotency check)
    $existingOffer = DB::table('listing_offers')
        ->where('listing_id', $id)
        ->where('code', $validated['code'])
        ->first();
    
    if ($existingOffer) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => "Offer code '{$validated['code']}' already exists for this listing"
        ], 422);
    }
    
    // Create offer
    $offerId = \Illuminate\Support\Str::uuid()->toString();
    $providerTenantId = $listing->tenant_id;
    $priceCurrency = $validated['price_currency'] ?? 'TRY';
    $attributes = $validated['attributes'] ?? null;
    
    DB::table('listing_offers')->insert([
        'id' => $offerId,
        'listing_id' => $id,
        'provider_tenant_id' => $providerTenantId,
        'code' => $validated['code'],
        'name' => $validated['name'],
        'price_amount' => $validated['price_amount'],
        'price_currency' => $priceCurrency,
        'billing_model' => $validated['billing_model'],
        'attributes_json' => $attributes ? json_encode($attributes) : null,
        'status' => 'active',
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    $response = [
        'id' => $offerId,
        'listing_id' => $id,
        'provider_tenant_id' => $providerTenantId,
        'code' => $validated['code'],
        'name' => $validated['name'],
        'price_amount' => $validated['price_amount'],
        'price_currency' => $priceCurrency,
        'billing_model' => $validated['billing_model'],
        'attributes' => $attributes,
        'status' => 'active',
        'created_at' => now()->toISOString(),
        'updated_at' => now()->toISOString()
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

// GET /v1/listings/{id}/offers - List offers for listing
Route::get('/v1/listings/{id}/offers', function ($id) {
    $offers = DB::table('listing_offers')
        ->where('listing_id', $id)
        ->where('status', 'active')
        ->orderBy('created_at', 'desc')
        ->get()
        ->map(function ($offer) {
            return [
                'id' => $offer->id,
                'listing_id' => $offer->listing_id,
                'provider_tenant_id' => $offer->provider_tenant_id,
                'code' => $offer->code,
                'name' => $offer->name,
                'price_amount' => $offer->price_amount,
                'price_currency' => $offer->price_currency,
                'billing_model' => $offer->billing_model,
                'attributes' => $offer->attributes_json ? json_decode($offer->attributes_json, true) : null,
                'status' => $offer->status,
                'created_at' => $offer->created_at,
                'updated_at' => $offer->updated_at
            ];
        });
    
    return response()->json($offers);
});

// GET /v1/offers/{id} - Get single offer
Route::get('/v1/offers/{id}', function ($id) {
    $offer = DB::table('listing_offers')->where('id', $id)->first();
    
    if (!$offer) {
        return response()->json([
            'error' => 'offer_not_found',
            'message' => "Offer with id {$id} not found"
        ], 404);
    }
    
    return response()->json([
        'id' => $offer->id,
        'listing_id' => $offer->listing_id,
        'provider_tenant_id' => $offer->provider_tenant_id,
        'code' => $offer->code,
        'name' => $offer->name,
        'price_amount' => $offer->price_amount,
        'price_currency' => $offer->price_currency,
        'billing_model' => $offer->billing_model,
        'attributes' => $offer->attributes_json ? json_decode($offer->attributes_json, true) : null,
        'status' => $offer->status,
        'created_at' => $offer->created_at,
        'updated_at' => $offer->updated_at
    ]);
});

// POST /v1/offers/{id}/activate - Activate offer
Route::post('/v1/offers/{id}/activate', function ($id, \Illuminate\Http\Request $request) {
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
    $membershipClient = new \App\Core\MembershipClient();
    $userId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
    $authToken = $request->header('Authorization');
    
    // Validate tenant_id format
    if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
        ], 403);
    }
    
    // Validate membership
    if (!$membershipClient->validateMembership($userId, $tenantIdHeader, $authToken)) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Invalid membership or tenant access denied'
        ], 403);
    }
    
    $tenantId = $tenantIdHeader;
    
    // Find offer
    $offer = DB::table('listing_offers')->where('id', $id)->first();
    if (!$offer) {
        return response()->json([
            'error' => 'offer_not_found',
            'message' => "Offer with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership (FORBIDDEN_SCOPE)
    if ($offer->provider_tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Only the offer owner can activate this offer'
        ], 403);
    }
    
    // Update status to active
    DB::table('listing_offers')
        ->where('id', $id)
        ->update([
            'status' => 'active',
            'updated_at' => now()
        ]);
    
    $updated = DB::table('listing_offers')->where('id', $id)->first();
    
    return response()->json([
        'id' => $updated->id,
        'listing_id' => $updated->listing_id,
        'provider_tenant_id' => $updated->provider_tenant_id,
        'code' => $updated->code,
        'name' => $updated->name,
        'price_amount' => $updated->price_amount,
        'price_currency' => $updated->price_currency,
        'billing_model' => $updated->billing_model,
        'attributes' => $updated->attributes_json ? json_decode($updated->attributes_json, true) : null,
        'status' => $updated->status,
        'updated_at' => $updated->updated_at
    ]);
});

// POST /v1/offers/{id}/deactivate - Deactivate offer
Route::post('/v1/offers/{id}/deactivate', function ($id, \Illuminate\Http\Request $request) {
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
    $membershipClient = new \App\Core\MembershipClient();
    $userId = $request->attributes->get('requester_user_id') ?? 'genesis-default';
    $authToken = $request->header('Authorization');
    
    // Validate tenant_id format
    if (!$membershipClient->isValidTenantIdFormat($tenantIdHeader)) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'X-Active-Tenant-Id must be a valid UUID format for store-scope endpoints'
        ], 403);
    }
    
    // Validate membership
    if (!$membershipClient->validateMembership($userId, $tenantIdHeader, $authToken)) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Invalid membership or tenant access denied'
        ], 403);
    }
    
    $tenantId = $tenantIdHeader;
    
    // Find offer
    $offer = DB::table('listing_offers')->where('id', $id)->first();
    if (!$offer) {
        return response()->json([
            'error' => 'offer_not_found',
            'message' => "Offer with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership (FORBIDDEN_SCOPE)
    if ($offer->provider_tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Only the offer owner can deactivate this offer'
        ], 403);
    }
    
    // Update status to inactive
    DB::table('listing_offers')
        ->where('id', $id)
        ->update([
            'status' => 'inactive',
            'updated_at' => now()
        ]);
    
    $updated = DB::table('listing_offers')->where('id', $id)->first();
    
    return response()->json([
        'id' => $updated->id,
        'listing_id' => $updated->listing_id,
        'provider_tenant_id' => $updated->provider_tenant_id,
        'code' => $updated->code,
        'name' => $updated->name,
        'price_amount' => $updated->price_amount,
        'price_currency' => $updated->price_currency,
        'billing_model' => $updated->billing_model,
        'attributes' => $updated->attributes_json ? json_decode($updated->attributes_json, true) : null,
        'status' => $updated->status,
        'updated_at' => $updated->updated_at
    ]);
});

