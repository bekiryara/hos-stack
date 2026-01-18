<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// Supply Spine Endpoints (WP-3)
// POST /v1/listings - Create DRAFT listing
Route::post('/v1/listings', function (\Illuminate\Http\Request $request) {
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
    
    $tenantId = $tenantIdHeader;
    
    // Validate required fields
    $validated = $request->validate([
        'category_id' => 'required|integer|exists:categories,id',
        'title' => 'required|string|max:120',
        'description' => 'nullable|string',
        'transaction_modes' => 'required|array|min:1',
        'transaction_modes.*' => 'string|in:sale,rental,reservation',
        'attributes' => 'nullable|array',
        'location' => 'nullable|array'
    ]);
    
    // Get category filter schema to validate required attributes
    $categoryId = $validated['category_id'];
    $hasNewFields = Schema::hasColumn('category_filter_schema', 'required');
    
    $requiredAttributes = [];
    if ($hasNewFields) {
        $requiredAttributes = DB::table('category_filter_schema')
            ->where('category_id', $categoryId)
            ->where('status', 'active')
            ->where('required', true)
            ->pluck('attribute_key')
            ->toArray();
    }
    
    // Validate required attributes exist in attributes_json
    $attributes = $validated['attributes'] ?? [];
    foreach ($requiredAttributes as $attrKey) {
        if (!isset($attributes[$attrKey])) {
            return response()->json([
                'error' => 'missing_required_attribute',
                'message' => "Required attribute '{$attrKey}' is missing",
                'required_attributes' => $requiredAttributes
            ], 422);
        }
    }
    
    // Type check attributes against attribute definitions
    if (!empty($attributes)) {
        $attributeDefs = DB::table('attributes')
            ->whereIn('key', array_keys($attributes))
            ->pluck('value_type', 'key')
            ->toArray();
        
        foreach ($attributes as $key => $value) {
            if (isset($attributeDefs[$key])) {
                $valueType = $attributeDefs[$key];
                $isValid = false;
                
                switch ($valueType) {
                    case 'number':
                        $isValid = is_numeric($value);
                        break;
                    case 'string':
                        $isValid = is_string($value);
                        break;
                    case 'boolean':
                        $isValid = is_bool($value) || in_array(strtolower($value), ['true', 'false', '1', '0', 'yes', 'no']);
                        break;
                    default:
                        $isValid = true; // Unknown types pass
                }
                
                if (!$isValid) {
                    return response()->json([
                        'error' => 'invalid_attribute_type',
                        'message' => "Attribute '{$key}' must be of type '{$valueType}'",
                        'attribute' => $key,
                        'value' => $value,
                        'expected_type' => $valueType
                    ], 422);
                }
            }
        }
    }
    
    // Get category to determine world/vertical
    $category = DB::table('categories')->where('id', $categoryId)->first();
    $world = $category->vertical ?? 'commerce'; // Default to 'commerce' if vertical not set
    
    // Create listing as DRAFT
    $listingId = \Illuminate\Support\Str::uuid()->toString();
    
    DB::table('listings')->insert([
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'world' => $world,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'description' => $validated['description'] ?? null,
        'transaction_modes_json' => json_encode($validated['transaction_modes']),
        'attributes_json' => !empty($attributes) ? json_encode($attributes) : null,
        'location_json' => isset($validated['location']) ? json_encode($validated['location']) : null,
        'status' => 'draft',
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    return response()->json([
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'status' => 'draft',
        'created_at' => now()->toISOString()
    ], 201);
});

// POST /v1/listings/{id}/publish - Publish listing
Route::post('/v1/listings/{id}/publish', function ($id, \Illuminate\Http\Request $request) {
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
    
    $tenantId = $tenantIdHeader;
    
    // Find listing
    $listing = DB::table('listings')->where('id', $id)->first();
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership
    if ($listing->tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'forbidden',
            'message' => 'Only the listing owner can publish this listing'
        ], 403);
    }
    
    // Check status is draft
    if ($listing->status !== 'draft') {
        return response()->json([
            'error' => 'invalid_status',
            'message' => "Listing must be in 'draft' status to publish. Current status: {$listing->status}"
        ], 422);
    }
    
    // Update status to published
    DB::table('listings')
        ->where('id', $id)
        ->update([
            'status' => 'published',
            'updated_at' => now()
        ]);
    
    $updated = DB::table('listings')->where('id', $id)->first();
    
    return response()->json([
        'id' => $updated->id,
        'tenant_id' => $updated->tenant_id,
        'category_id' => $updated->category_id,
        'title' => $updated->title,
        'status' => $updated->status,
        'updated_at' => $updated->updated_at
    ]);
});

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

// GET /v1/listings - Search listings
Route::get('/v1/listings', function (\Illuminate\Http\Request $request) {
    $query = DB::table('listings');
    
    // Filter by category_id if provided
    if ($request->has('category_id')) {
        $query->where('category_id', $request->input('category_id'));
    }
    
    // Filter by status (default: published)
    $status = $request->input('status', 'published');
    $query->where('status', $status);
    
    // WP-12.1: Filter by tenant_id if provided (Account Portal Store view)
    // Store scope requires X-Active-Tenant-Id header
    if ($request->has('tenant_id')) {
        $tenantId = $request->input('tenant_id');
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
        
        // Verify X-Active-Tenant-Id matches tenant_id parameter for security
        if ($tenantIdHeader !== $tenantId) {
            return response()->json([
                'error' => 'FORBIDDEN_SCOPE',
                'message' => 'X-Active-Tenant-Id header must match tenant_id parameter'
            ], 403);
        }
        
        $query->where('tenant_id', $tenantId);
    }
    
    // Filter by attributes (simple key-value matching)
    if ($request->has('attrs')) {
        $attrs = $request->input('attrs');
        if (is_array($attrs)) {
            foreach ($attrs as $key => $value) {
                $query->whereRaw("attributes_json->>? = ?", [$key, $value]);
            }
        }
    }
    
    // WP-12: Pagination (per_page default 20, max 50)
    $page = max(1, (int)$request->input('page', 1));
    $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
    $offset = ($page - 1) * $perPage;
    
    // Get total count before pagination
    $total = $query->count();
    
    $listings = $query->orderBy('created_at', 'desc')
        ->offset($offset)
        ->limit($perPage)
        ->get()
        ->map(function ($listing) {
            return [
                'id' => $listing->id,
                'tenant_id' => $listing->tenant_id,
                'category_id' => $listing->category_id,
                'title' => $listing->title,
                'description' => $listing->description,
                'status' => $listing->status,
                'transaction_modes' => $listing->transaction_modes_json ? json_decode($listing->transaction_modes_json, true) : [],
                'attributes' => $listing->attributes_json ? json_decode($listing->attributes_json, true) : [],
                'location' => $listing->location_json ? json_decode($listing->location_json, true) : null,
                'created_at' => $listing->created_at,
                'updated_at' => $listing->updated_at
            ];
        })
        ->values()
        ->all();
    
    // WP-3.1: Response MUST always be a JSON array (contract requirement)
    // Empty results return [] (empty array)
    return response()->json($listings);
});

// GET /v1/listings/{id} - Get single listing
Route::get('/v1/listings/{id}', function ($id) {
    $listing = DB::table('listings')->where('id', $id)->first();
    
    if (!$listing) {
        return response()->json([
            'error' => 'listing_not_found',
            'message' => "Listing with id {$id} not found"
        ], 404);
    }
    
    return response()->json([
        'id' => $listing->id,
        'tenant_id' => $listing->tenant_id,
        'category_id' => $listing->category_id,
        'title' => $listing->title,
        'description' => $listing->description,
        'status' => $listing->status,
        'transaction_modes' => $listing->transaction_modes_json ? json_decode($listing->transaction_modes_json, true) : [],
        'attributes' => $listing->attributes_json ? json_decode($listing->attributes_json, true) : [],
        'location' => $listing->location_json ? json_decode($listing->location_json, true) : null,
        'created_at' => $listing->created_at,
        'updated_at' => $listing->updated_at
    ]);
});

// WP-8: Search & Discovery Thin Slice (Read Spine)
// GET /api/v1/search - Search listings with filters and availability
Route::get('/v1/search', function (\Illuminate\Http\Request $request) {
    
    // Validate required parameters
    $validated = $request->validate([
        'category_id' => 'required|integer|exists:categories,id',
        'city' => 'nullable|string|max:255',
        'date_from' => 'nullable|date',
        'date_to' => 'nullable|date|after_or_equal:date_from',
        'capacity_min' => 'nullable|integer|min:1',
        'transaction_mode' => 'nullable|string|in:sale,rental,reservation',
        'page' => 'nullable|integer|min:1',
        'per_page' => 'nullable|integer|min:1|max:50'
    ], [
        'category_id.required' => 'category_id parameter is required',
        'category_id.exists' => 'category_id not found',
        'date_to.after_or_equal' => 'date_to must be after or equal to date_from',
        'per_page.max' => 'per_page cannot exceed 50'
    ]);
    
    // Get all category IDs including descendants (recursive)
    $categoryId = (int) $validated['category_id'];
    
    // Helper function to get all descendant category IDs
    $getDescendantCategoryIds = function($parentId) use (&$getDescendantCategoryIds) {
        $categoryIds = [$parentId];
        $children = DB::table('categories')
            ->where('parent_id', $parentId)
            ->where('status', 'active')
            ->pluck('id')
            ->toArray();
        
        foreach ($children as $childId) {
            $categoryIds = array_merge($categoryIds, $getDescendantCategoryIds($childId));
        }
        
        return $categoryIds;
    };
    
    $categoryIds = $getDescendantCategoryIds($categoryId);
    
    // Build query - only published listings
    $query = DB::table('listings')
        ->where('status', 'published')
        ->whereIn('category_id', $categoryIds);
    
    // Filter by city (from location_json)
    if ($request->has('city')) {
        $city = $request->input('city');
        $query->whereRaw("location_json->>'city' = ?", [$city]);
    }
    
    // Filter by capacity_min (from attributes_json)
    if ($request->has('capacity_min')) {
        $capacityMin = (int) $request->input('capacity_min');
        // Check if capacity_max exists and is >= capacity_min
        $query->whereRaw("CAST(attributes_json->>'capacity_max' AS INTEGER) >= ?", [$capacityMin]);
    }
    
    // Filter by transaction_mode (from transaction_modes_json)
    if ($request->has('transaction_mode')) {
        $transactionMode = $request->input('transaction_mode');
        // Check if transaction_modes_json array contains the mode
        $query->whereRaw("transaction_modes_json::text LIKE ?", ['%' . $transactionMode . '%']);
    }
    
    // Availability logic: exclude listings with overlapping reservations/rentals
    if ($request->has('date_from') && $request->has('date_to')) {
        $dateFrom = $request->input('date_from');
        $dateTo = $request->input('date_to');
        
        // Get transaction_mode to determine which availability check to use
        $transactionMode = $request->input('transaction_mode');
        $excludedListingIds = [];
        
        // For reservation listings: exclude overlapping accepted/requested reservations
        if (!$transactionMode || $transactionMode === 'reservation') {
            $excludedReservationListingIds = DB::table('reservations')
                ->whereIn('status', ['requested', 'accepted'])
                ->where(function ($q) use ($dateFrom, $dateTo) {
                    // Overlap: reservation starts before date_to AND ends after date_from
                    $q->where('slot_start', '<', $dateTo)
                      ->where('slot_end', '>', $dateFrom);
                })
                ->pluck('listing_id')
                ->unique()
                ->toArray();
            
            $excludedListingIds = array_merge($excludedListingIds, $excludedReservationListingIds);
        }
        
        // For rental listings: exclude overlapping active/accepted/requested rentals
        if (!$transactionMode || $transactionMode === 'rental') {
            $excludedRentalListingIds = DB::table('rentals')
                ->whereIn('status', ['requested', 'accepted', 'active'])
                ->where(function ($q) use ($dateFrom, $dateTo) {
                    // Overlap: rental starts before date_to AND ends after date_from
                    $q->where('start_at', '<', $dateTo)
                      ->where('end_at', '>', $dateFrom);
                })
                ->pluck('listing_id')
                ->unique()
                ->toArray();
            
            $excludedListingIds = array_merge($excludedListingIds, $excludedRentalListingIds);
        }
        
        // Remove duplicates and exclude listings
        if (!empty($excludedListingIds)) {
            $excludedListingIds = array_unique($excludedListingIds);
            $query->whereNotIn('id', $excludedListingIds);
        }
    }
    
    // Deterministic ordering (created_at DESC)
    $query->orderBy('created_at', 'desc');
    
    // Pagination
    $page = (int) ($request->input('page', 1));
    $perPage = min(50, max(1, (int) ($request->input('per_page', 20))));
    $offset = ($page - 1) * $perPage;
    
    // Get total count before pagination
    $total = $query->count();
    
    // Apply pagination
    $listings = $query->offset($offset)
        ->limit($perPage)
        ->get()
        ->map(function ($listing) {
            return [
                'id' => $listing->id,
                'tenant_id' => $listing->tenant_id,
                'category_id' => $listing->category_id,
                'title' => $listing->title,
                'description' => $listing->description,
                'status' => $listing->status,
                'transaction_modes' => $listing->transaction_modes_json ? json_decode($listing->transaction_modes_json, true) : [],
                'attributes' => $listing->attributes_json ? json_decode($listing->attributes_json, true) : [],
                'location' => $listing->location_json ? json_decode($listing->location_json, true) : null,
                'created_at' => $listing->created_at,
                'updated_at' => $listing->updated_at
            ];
        });
    
    // Empty result is VALID - return empty array with pagination info
    return response()->json([
        'data' => $listings,
        'meta' => [
            'total' => $total,
            'page' => $page,
            'per_page' => $perPage,
            'total_pages' => (int) ceil($total / $perPage)
        ]
    ]);
});

