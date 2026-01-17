<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use App\Worlds\WorldRegistry;

// Helper function to generate deterministic UUID from string
if (!function_exists('generate_tenant_uuid')) {
    function generate_tenant_uuid($tenantString) {
        // Use MD5 hash to create deterministic UUID-like string
        $hash = md5('tenant-namespace-' . $tenantString);
        return sprintf('%08s-%04s-%04s-%04s-%012s',
            substr($hash, 0, 8),
            substr($hash, 8, 4),
            substr($hash, 12, 4),
            substr($hash, 16, 4),
            substr($hash, 20, 12)
        );
    }
}

Route::get('/ping', function () {
    return response()->json([
        'api'  => 'PAZAR',
        'ping' => 'OK'
    ]);
});

// GENESIS World Status (SPEC §24.4, WP-1)
Route::get('/world/status', function () {
    $registry = new WorldRegistry();
    $worldKey = 'marketplace';
    
    // Check if marketplace world is enabled (marketplace = commerce world in registry)
    // For minimal implementation: check if 'commerce' is enabled
    $isEnabled = $registry->isEnabled('commerce');
    
    // Read version from VERSION file or env (minimal: use env or default)
    $version = env('APP_VERSION', '1.4.0');
    $phase = 'GENESIS';
    
    // Optional: commit hash (if available)
    $commit = env('GIT_COMMIT', null);
    if ($commit) {
        $commit = substr($commit, 0, 7); // short SHA
    }
    
    // If world is disabled, return 503 + WORLD_DISABLED (SPEC §17.5)
    if (!$isEnabled) {
        return response()->json([
            'error_code' => 'WORLD_DISABLED',
            'message' => "World '{$worldKey}' is disabled",
            'world_key' => $worldKey
        ], 503);
    }
    
    // Build response (SPEC §24.4 format)
    $response = [
        'world_key' => $worldKey,
        'availability' => 'ONLINE',
        'phase' => $phase,
        'version' => $version
    ];
    
    // Add commit if available
    if ($commit) {
        $response['commit'] = $commit;
    }
    
    return response()->json($response);
});

// Catalog Spine Endpoints (SPEC §6.2, WP-2)
// GET /v1/categories (tree format)
Route::get('/v1/categories', function () {
    
    // Fetch all categories with parent relationships
    $categories = DB::table('categories')
        ->where('status', 'active')
        ->orderBy('sort_order')
        ->get()
        ->map(function ($cat) {
            return [
                'id' => $cat->id,
                'parent_id' => $cat->parent_id,
                'slug' => $cat->slug,
                'name' => $cat->name,
                'vertical' => $cat->vertical,
                'status' => $cat->status,
            ];
        })
        ->toArray();
    
    // Build tree structure (recursive function)
    function buildTree($categories, $parentId = null) {
        $branch = [];
        foreach ($categories as $category) {
            if ($category['parent_id'] == $parentId) {
                $children = buildTree($categories, $category['id']);
                if (!empty($children)) {
                    $category['children'] = $children;
                }
                $branch[] = $category;
            }
        }
        return $branch;
    }
    
    $tree = buildTree($categories);
    
    return response()->json($tree);
});

// GET /v1/categories/{id}/filter-schema
Route::get('/v1/categories/{id}/filter-schema', function ($id) {
    
    // Verify category exists
    $category = DB::table('categories')->where('id', $id)->first();
    if (!$category) {
        return response()->json([
            'error' => 'category_not_found',
            'message' => "Category with id {$id} not found"
        ], 404);
    }
    
    // Fetch filter schema for this category
    // Check if new fields exist (after migration)
    $hasNewFields = Schema::hasColumn('category_filter_schema', 'ui_component');
    
    $selectFields = [
        'category_filter_schema.id',
        'category_filter_schema.attribute_key',
        'category_filter_schema.status',
        'category_filter_schema.sort_order',
        'attributes.value_type',
        'attributes.unit',
        'attributes.description'
    ];
    
    if ($hasNewFields) {
        $selectFields = array_merge($selectFields, [
            'category_filter_schema.ui_component',
            'category_filter_schema.required',
            'category_filter_schema.filter_mode',
            'category_filter_schema.rules_json'
        ]);
    }
    
    $schema = DB::table('category_filter_schema')
        ->join('attributes', 'category_filter_schema.attribute_key', '=', 'attributes.key')
        ->where('category_filter_schema.category_id', $id)
        ->where('category_filter_schema.status', 'active')
        ->orderBy('category_filter_schema.sort_order')
        ->select($selectFields)
        ->get()
        ->map(function ($item) use ($hasNewFields) {
            $result = [
                'attribute_key' => $item->attribute_key,
                'value_type' => $item->value_type,
                'unit' => $item->unit,
                'description' => $item->description,
                'status' => $item->status,
                'sort_order' => $item->sort_order,
            ];
            
            // Add new fields if migration has run
            if ($hasNewFields) {
                $result['ui_component'] = $item->ui_component;
                $result['required'] = (bool) $item->required;
                $result['filter_mode'] = $item->filter_mode;
                
                // Parse rules_json if present
                if ($item->rules_json) {
                    $rules = json_decode($item->rules_json, true);
                    if ($rules) {
                        $result['rules'] = $rules;
                    }
                }
            }
            
            return $result;
        })
        ->toArray();
    
    return response()->json([
        'category_id' => (int) $id,
        'category_slug' => $category->slug,
        'filters' => $schema
    ]);
});

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
    
    // Validate tenant_id is valid UUID format (since listings.tenant_id is UUID type)
    // For testing: generate deterministic UUID from tenant string if not valid UUID
    if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $tenantIdHeader)) {
        // Generate deterministic UUID from tenant string
        $tenantId = generate_tenant_uuid($tenantIdHeader);
        // TODO: In production, enforce UUID format or change tenant_id column to string/varchar
    } else {
        $tenantId = $tenantIdHeader;
    }
    
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
    
    // Validate tenant_id is valid UUID format (since listings.tenant_id is UUID type)
    // For testing: generate deterministic UUID from tenant string if not valid UUID
    if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $tenantIdHeader)) {
        // Generate deterministic UUID from tenant string
        $tenantId = generate_tenant_uuid($tenantIdHeader);
        // TODO: In production, enforce UUID format or change tenant_id column to string/varchar
    } else {
        $tenantId = $tenantIdHeader;
    }
    
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
    
    // Filter by attributes (simple key-value matching)
    if ($request->has('attrs')) {
        $attrs = $request->input('attrs');
        if (is_array($attrs)) {
            foreach ($attrs as $key => $value) {
                $query->whereRaw("attributes_json->>? = ?", [$key, $value]);
            }
        }
    }
    
    $listings = $query->orderBy('created_at', 'desc')->get()->map(function ($listing) {
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

// Reservation Spine Endpoints (WP-4)
// POST /v1/reservations - Create reservation
Route::post('/v1/reservations', function (\Illuminate\Http\Request $request) {
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
        'slot_start' => 'required|date',
        'slot_end' => 'required|date|after:slot_start',
        'party_size' => 'required|integer|min:1'
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
            'error' => 'listing_not_published',
            'message' => "Listing must be published to create reservations. Current status: {$listing->status}"
        ], 422);
    }
    
    // Idempotency check (MUST be before overlap check to avoid false conflicts)
    // For GENESIS: use requester_user_id if available, else use a default scope
    $scopeType = 'user'; // Default for GENESIS
    $scopeId = $request->header('X-Requester-User-Id') ?? 'genesis-default';
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
    
    // Check capacity_max constraint: party_size <= capacity_max
    $attributes = $listing->attributes_json ? json_decode($listing->attributes_json, true) : [];
    if (isset($attributes['capacity_max'])) {
        $capacityMax = (int) $attributes['capacity_max'];
        if ($validated['party_size'] > $capacityMax) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => "party_size ({$validated['party_size']}) exceeds capacity_max ({$capacityMax})",
                'party_size' => $validated['party_size'],
                'capacity_max' => $capacityMax
            ], 422);
        }
    } else {
        // If capacity_max not set, return VALIDATION_ERROR
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'listing.attributes_json.capacity_max is required but not found'
        ], 422);
    }
    
    // Check slot overlap: accepted/requested reservations that overlap same listing
    $slotStart = new \DateTime($validated['slot_start']);
    $slotEnd = new \DateTime($validated['slot_end']);
    
    $overlapping = DB::table('reservations')
        ->where('listing_id', $validated['listing_id'])
        ->whereIn('status', ['requested', 'accepted'])
        ->where(function ($query) use ($slotStart, $slotEnd) {
            $query->where(function ($q) use ($slotStart, $slotEnd) {
                // Reservation starts before our end and ends after our start
                $q->where('slot_start', '<', $slotEnd->format('Y-m-d H:i:s'))
                  ->where('slot_end', '>', $slotStart->format('Y-m-d H:i:s'));
            });
        })
        ->first();
    
    if ($overlapping) {
        return response()->json([
            'error' => 'CONFLICT',
            'message' => 'Slot overlaps with existing reservation',
            'conflicting_reservation_id' => $overlapping->id
        ], 409);
    }
    
    // Create reservation
    $reservationId = \Illuminate\Support\Str::uuid()->toString();
    $providerTenantId = $listing->tenant_id;
    $requesterUserId = $request->header('X-Requester-User-Id') ? generate_tenant_uuid($request->header('X-Requester-User-Id')) : null;
    
    DB::table('reservations')->insert([
        'id' => $reservationId,
        'listing_id' => $validated['listing_id'],
        'provider_tenant_id' => $providerTenantId,
        'requester_user_id' => $requesterUserId,
        'slot_start' => $slotStart->format('Y-m-d H:i:s'),
        'slot_end' => $slotEnd->format('Y-m-d H:i:s'),
        'party_size' => $validated['party_size'],
        'status' => 'requested',
        'created_at' => now(),
        'updated_at' => now()
    ]);
    
    $response = [
        'id' => $reservationId,
        'listing_id' => $validated['listing_id'],
        'provider_tenant_id' => $providerTenantId,
        'requester_user_id' => $requesterUserId,
        'slot_start' => $slotStart->format('Y-m-d\TH:i:s\Z'),
        'slot_end' => $slotEnd->format('Y-m-d\TH:i:s\Z'),
        'party_size' => $validated['party_size'],
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
    
    // Create messaging thread for reservation (context-only integration, WP-5)
    // Non-fatal: if messaging service is unavailable, reservation still succeeds
    try {
        $messagingClient = new \App\Messaging\MessagingClient();
        $participants = [];
        
        if ($requesterUserId) {
            $participants[] = ['type' => 'user', 'id' => $requesterUserId];
        }
        if ($providerTenantId) {
            $participants[] = ['type' => 'tenant', 'id' => $providerTenantId];
        }
        
        if (!empty($participants)) {
            $messagingClient->upsertThread('reservation', $reservationId, $participants);
        }
    } catch (\Exception $e) {
        // Non-fatal: log but do not fail reservation creation
        \Illuminate\Support\Facades\Log::warning('messaging.thread_creation.failed', [
            'reservation_id' => $reservationId,
            'error' => $e->getMessage()
        ]);
    }
    
    return response()->json($response, 201);
});

// POST /v1/reservations/{id}/accept - Accept reservation
Route::post('/v1/reservations/{id}/accept', function ($id, \Illuminate\Http\Request $request) {
    // Require X-Active-Tenant-Id header
    $tenantIdHeader = $request->header('X-Active-Tenant-Id');
    if (!$tenantIdHeader) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'X-Active-Tenant-Id header is required'
        ], 400);
    }
    
    // Convert tenant header to UUID if needed
    if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $tenantIdHeader)) {
        $tenantId = generate_tenant_uuid($tenantIdHeader);
    } else {
        $tenantId = $tenantIdHeader;
    }
    
    // Find reservation
    $reservation = DB::table('reservations')->where('id', $id)->first();
    if (!$reservation) {
        return response()->json([
            'error' => 'reservation_not_found',
            'message' => "Reservation with id {$id} not found"
        ], 404);
    }
    
    // Check tenant ownership (FORBIDDEN_SCOPE)
    if ($reservation->provider_tenant_id !== $tenantId) {
        return response()->json([
            'error' => 'FORBIDDEN_SCOPE',
            'message' => 'Only the listing owner can accept this reservation'
        ], 403);
    }
    
    // Check status is requested (state transition validation)
    if ($reservation->status !== 'requested') {
        return response()->json([
            'error' => 'INVALID_STATE',
            'message' => "Reservation must be in 'requested' status to accept. Current status: {$reservation->status}"
        ], 422);
    }
    
    // Update status to accepted (atomic operation)
    // NOTE: Accept does NOT perform overlap checks - only create does
    // Accept only validates: tenant ownership, state transition (requested -> accepted)
    $updated = DB::table('reservations')
        ->where('id', $id)
        ->where('status', 'requested') // Atomic: only update if still requested
        ->update([
            'status' => 'accepted',
            'updated_at' => now()
        ]);
    
    // Verify update succeeded (race condition check)
    if ($updated === 0) {
        // Status changed between check and update (race condition or idempotency)
        $current = DB::table('reservations')->where('id', $id)->first();
        if ($current && $current->status === 'accepted') {
            // Already accepted (idempotent accept)
            $reservation = $current;
        } else {
            return response()->json([
                'error' => 'INTERNAL_ERROR',
                'message' => 'Failed to update reservation status'
            ], 500);
        }
    } else {
        // Reload updated reservation
        $reservation = DB::table('reservations')->where('id', $id)->first();
    }
    
    return response()->json([
        'id' => $reservation->id,
        'listing_id' => $reservation->listing_id,
        'provider_tenant_id' => $reservation->provider_tenant_id,
        'requester_user_id' => $reservation->requester_user_id,
        'slot_start' => $reservation->slot_start,
        'slot_end' => $reservation->slot_end,
        'party_size' => $reservation->party_size,
        'status' => $reservation->status,
        'updated_at' => $reservation->updated_at
    ]);
});

// Order Spine Endpoints (WP-6)
// POST /v1/orders - Create order
Route::post('/v1/orders', function (\Illuminate\Http\Request $request) {
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
    $scopeType = 'user'; // Personal scope for buyer
    $scopeId = $request->header('X-Requester-User-Id') ? generate_tenant_uuid($request->header('X-Requester-User-Id')) : 'genesis-default';
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
    $buyerUserId = $request->header('X-Requester-User-Id') ? generate_tenant_uuid($request->header('X-Requester-User-Id')) : null;
    
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

// GET /v1/reservations/{id} - Get reservation
Route::get('/v1/reservations/{id}', function ($id) {
    $reservation = DB::table('reservations')->where('id', $id)->first();
    
    if (!$reservation) {
        return response()->json([
            'error' => 'reservation_not_found',
            'message' => "Reservation with id {$id} not found"
        ], 404);
    }
    
    return response()->json([
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
    ]);
});

// Rental Spine Endpoints (WP-7)
// POST /v1/rentals - Create rental request
Route::post('/v1/rentals', function (\Illuminate\Http\Request $request) {
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
    
    // Idempotency check (MUST be before overlap check to avoid false conflicts)
    $scopeType = 'user'; // Default for GENESIS
    $scopeId = $request->header('X-Requester-User-Id') ? generate_tenant_uuid($request->header('X-Requester-User-Id')) : 'genesis-default';
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
    $rentalId = \Illuminate\Support\Str::uuid()->toString();
    $providerTenantId = $listing->tenant_id;
    $renterUserId = $request->header('X-Requester-User-Id') ? generate_tenant_uuid($request->header('X-Requester-User-Id')) : null;
    
    if (!$renterUserId) {
        return response()->json([
            'error' => 'VALIDATION_ERROR',
            'message' => 'X-Requester-User-Id header is required'
        ], 422);
    }
    
    DB::table('rentals')->insert([
        'id' => $rentalId,
        'listing_id' => $validated['listing_id'],
        'renter_user_id' => $renterUserId,
        'provider_tenant_id' => $providerTenantId,
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
Route::post('/v1/rentals/{id}/accept', function ($id, \Illuminate\Http\Request $request) {
    // Require X-Active-Tenant-Id header
    $tenantIdHeader = $request->header('X-Active-Tenant-Id');
    if (!$tenantIdHeader) {
        return response()->json([
            'error' => 'missing_header',
            'message' => 'X-Active-Tenant-Id header is required'
        ], 400);
    }
    
    // Convert tenant header to UUID if needed
    if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $tenantIdHeader)) {
        $tenantId = generate_tenant_uuid($tenantIdHeader);
    } else {
        $tenantId = $tenantIdHeader;
    }
    
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
        'start_at' => $rental->start_at,
        'end_at' => $rental->end_at,
        'status' => $rental->status,
        'updated_at' => $rental->updated_at
    ]);
});

// GET /v1/rentals/{id} - Get rental
Route::get('/v1/rentals/{id}', function ($id) {
    $rental = DB::table('rentals')->where('id', $id)->first();
    
    if (!$rental) {
        return response()->json([
            'error' => 'rental_not_found',
            'message' => "Rental with id {$id} not found"
        ], 404);
    }
    
    return response()->json([
        'id' => $rental->id,
        'listing_id' => $rental->listing_id,
        'renter_user_id' => $rental->renter_user_id,
        'provider_tenant_id' => $rental->provider_tenant_id,
        'start_at' => $rental->start_at,
        'end_at' => $rental->end_at,
        'status' => $rental->status,
        'created_at' => $rental->created_at,
        'updated_at' => $rental->updated_at
    ]);
});
