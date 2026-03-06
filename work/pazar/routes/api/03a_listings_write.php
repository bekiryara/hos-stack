<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

if (!function_exists('pazar_listing_write_tenant_id_or_error')) {
    function pazar_listing_write_tenant_id_or_error(\Illuminate\Http\Request $request) {
        $tenantId = $request->attributes->get('tenant_id');
        if (!$tenantId) {
            return response()->json([
                'error' => 'missing_header',
                'message' => 'X-Active-Tenant-Id header is required'
            ], 400);
        }
        return $tenantId;
    }
}

if (!function_exists('pazar_listing_write_normalize_currency')) {
    function pazar_listing_write_normalize_currency($rawCurrency): string {
        return is_string($rawCurrency) && trim($rawCurrency) !== ''
            ? strtoupper(trim($rawCurrency))
            : 'TRY';
    }
}

if (!function_exists('pazar_listing_write_response')) {
    function pazar_listing_write_response(object $listing): array {
        return [
            'id' => $listing->id,
            'tenant_id' => $listing->tenant_id,
            'category_id' => $listing->category_id,
            'title' => $listing->title,
            'price_amount' => $listing->price_amount,
            'currency' => $listing->currency,
            'status' => $listing->status,
            'created_at' => $listing->created_at,
            'updated_at' => $listing->updated_at,
        ];
    }
}

if (!function_exists('pazar_listing_validate_location_by_scope')) {
    function pazar_listing_validate_location_by_scope(int $categoryId, $locationRaw) {
        $intent = pazar_category_intent_schema($categoryId);
        $scope = isset($intent['location_scope']) ? (string) $intent['location_scope'] : 'point';
        $location = is_array($locationRaw) ? $locationRaw : [];
        $trim = static function ($v): string {
            return is_string($v) ? trim($v) : '';
        };

        if ($scope === 'none') {
            return null;
        }

        if ($scope === 'city') {
            $city = $trim($location['city'] ?? '');
            if ($city === '') {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'location.city is required for location_scope=city'
                ], 422);
            }
            return ['city' => $city];
        }

        if ($scope === 'point') {
            $city = $trim($location['city'] ?? '');
            $district = $trim($location['district'] ?? '');
            $neighborhood = $trim($location['neighborhood'] ?? '');
            if ($city === '' || $district === '' || $neighborhood === '') {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'location.city, location.district and location.neighborhood are required for location_scope=point'
                ], 422);
            }
            $normalized = [
                'city' => $city,
                'district' => $district,
                'neighborhood' => $neighborhood,
            ];
            $street = $trim($location['street'] ?? '');
            if ($street !== '') $normalized['street'] = $street;
            $buildingNo = $trim($location['building_no'] ?? '');
            if ($buildingNo !== '') $normalized['building_no'] = $buildingNo;
            $doorNo = $trim($location['door_no'] ?? '');
            if ($doorNo !== '') $normalized['door_no'] = $doorNo;
            $address = $trim($location['address_line'] ?? '');
            if ($address !== '') $normalized['address_line'] = $address;

            $lat = $location['lat'] ?? null;
            $lng = $location['lng'] ?? null;
            if ($lat !== null && $lng !== null && is_numeric($lat) && is_numeric($lng)) {
                $normalized['lat'] = (float) $lat;
                $normalized['lng'] = (float) $lng;
            }
            return $normalized;
        }

        if ($scope === 'service_area') {
            $rows = [];
            $serviceArea = $location['service_area'] ?? null;
            if (!is_array($serviceArea) || count($serviceArea) === 0) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'location.service_area must include at least one city for location_scope=service_area'
                ], 422);
            }

            foreach ($serviceArea as $row) {
                if (!is_array($row)) continue;
                $city = $trim($row['city'] ?? '');
                if ($city === '') continue;
                $allDistricts = (bool) ($row['all_districts'] ?? false);
                $districts = [];
                if (!$allDistricts) {
                    $rawDistricts = $row['districts'] ?? [];
                    if (is_array($rawDistricts)) {
                        foreach ($rawDistricts as $d) {
                            $v = $trim($d);
                            if ($v !== '') $districts[] = $v;
                        }
                    }
                    if (count($districts) === 0) {
                        return response()->json([
                            'error' => 'VALIDATION_ERROR',
                            'message' => "location.service_area city '{$city}' requires non-empty districts when all_districts=false"
                        ], 422);
                    }
                }
                $rows[] = [
                    'city' => $city,
                    'all_districts' => $allDistricts,
                    'districts' => $allDistricts ? [] : array_values(array_unique($districts)),
                ];
            }

            if (count($rows) === 0) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'location.service_area must include at least one valid city'
                ], 422);
            }

            return ['service_area' => $rows];
        }

        return is_array($locationRaw) ? $locationRaw : null;
    }
}

if (!function_exists('pazar_listing_location_column_updates')) {
    function pazar_listing_location_column_updates(int $categoryId, $normalizedLocation): array {
        if (!Schema::hasColumn('listings', 'location_scope')) {
            return [];
        }

        $intent = pazar_category_intent_schema($categoryId);
        $scope = isset($intent['location_scope']) ? (string) $intent['location_scope'] : 'point';

        $updates = [
            'location_scope' => $scope,
            'location_city' => null,
            'location_district' => null,
            'location_neighborhood' => null,
            'location_street' => null,
            'location_building_no' => null,
            'location_door_no' => null,
            'location_address_line' => null,
            'location_lat' => null,
            'location_lng' => null,
        ];

        if (!is_array($normalizedLocation)) {
            return $updates;
        }

        $trim = static function ($v): string {
            return is_string($v) ? trim($v) : '';
        };

        if ($scope === 'city' || $scope === 'point') {
            $updates['location_city'] = $trim($normalizedLocation['city'] ?? '') ?: null;
        }
        if ($scope === 'point') {
            $updates['location_district'] = $trim($normalizedLocation['district'] ?? '') ?: null;
            $updates['location_neighborhood'] = $trim($normalizedLocation['neighborhood'] ?? '') ?: null;
            $updates['location_street'] = $trim($normalizedLocation['street'] ?? '') ?: null;
            $updates['location_building_no'] = $trim($normalizedLocation['building_no'] ?? '') ?: null;
            $updates['location_door_no'] = $trim($normalizedLocation['door_no'] ?? '') ?: null;
            $updates['location_address_line'] = $trim($normalizedLocation['address_line'] ?? '') ?: null;

            $lat = $normalizedLocation['lat'] ?? null;
            $lng = $normalizedLocation['lng'] ?? null;
            if ($lat !== null && $lng !== null && is_numeric($lat) && is_numeric($lng)) {
                $updates['location_lat'] = (float) $lat;
                $updates['location_lng'] = (float) $lng;
            }
        }

        return $updates;
    }
}

if (!function_exists('pazar_listing_sync_service_areas')) {
    function pazar_listing_sync_service_areas(string $listingId, $normalizedLocation): void {
        if (!Schema::hasTable('listing_service_areas')) return;

        DB::table('listing_service_areas')->where('listing_id', $listingId)->delete();

        if (!is_array($normalizedLocation) || !isset($normalizedLocation['service_area']) || !is_array($normalizedLocation['service_area'])) {
            return;
        }

        $rows = [];
        foreach ($normalizedLocation['service_area'] as $row) {
            if (!is_array($row)) continue;
            $city = isset($row['city']) && is_string($row['city']) ? trim($row['city']) : '';
            if ($city === '') continue;
            $allDistricts = (bool) ($row['all_districts'] ?? false);
            $districts = [];
            if (!$allDistricts) {
                $rawDistricts = $row['districts'] ?? [];
                if (is_array($rawDistricts)) {
                    foreach ($rawDistricts as $d) {
                        if (!is_string($d)) continue;
                        $v = trim($d);
                        if ($v !== '') $districts[] = $v;
                    }
                }
            }
            $rows[] = [
                'listing_id' => $listingId,
                'city' => $city,
                'all_districts' => $allDistricts,
                'districts_json' => $allDistricts ? json_encode([]) : json_encode(array_values(array_unique($districts))),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        if (!empty($rows)) {
            DB::table('listing_service_areas')->insert($rows);
        }
    }
}

if (!function_exists('pazar_listing_write_owned_listing_or_error')) {
    function pazar_listing_write_owned_listing_or_error(string $listingId, string $tenantId) {
        $listing = DB::table('listings')->where('id', $listingId)->first();
        if (!$listing) {
            return response()->json([
                'error' => 'listing_not_found',
                'message' => "Listing with id {$listingId} not found"
            ], 404);
        }

        if ($listing->tenant_id !== $tenantId) {
            return response()->json([
                'error' => 'forbidden',
                'message' => 'Only the listing owner can modify this listing'
            ], 403);
        }

        return $listing;
    }
}

// Supply Spine Endpoints (WP-3)
// POST /v1/listings - Create DRAFT listing
// WP-8: STORE persona requires X-Active-Tenant-Id header (persona.scope:store)
// WP-26: Tenant scope enforced via tenant.scope middleware
// WP-29: Auth required via auth.any middleware
// WP-50: AuthAny middleware validates JWT tokens
// WP-48: Use full class name to avoid Laravel terminate phase alias resolution issue
$createListingMiddleware = [\App\Http\Middleware\PersonaScope::class . ':store'];
$createListingMiddleware[] = 'auth.any';
$createListingMiddleware[] = 'auth.ctx';
$createListingMiddleware[] = 'tenant.scope';
Route::middleware($createListingMiddleware)->post('/v1/listings', function (\Illuminate\Http\Request $request) {
    $tenantId = pazar_listing_write_tenant_id_or_error($request);
    if ($tenantId instanceof \Illuminate\Http\JsonResponse) return $tenantId;
    
    // Validate required fields
    $validated = $request->validate([
        // Phase-1 enforcement: category must be active (aligns with read path semantics).
        'category_id' => 'required|integer|exists:categories,id,status,active',
        'title' => 'required|string|max:120',
        'description' => 'nullable|string',
        'price_amount' => 'nullable|integer|min:0',
        'currency' => 'nullable|string|size:3',
        'transaction_modes' => 'required|array|min:1',
        'transaction_modes.*' => 'string|in:' . implode(',', pazar_canonical_transaction_modes()),
        'attributes' => 'nullable|array',
        'location' => 'nullable|array'
    ]);
    
    // Single-source-of-truth: validate + normalize category/attributes/transaction modes via guard.
    $categoryId = (int) $validated['category_id'];
    $attributes = $validated['attributes'] ?? [];
    $transactionModes = $validated['transaction_modes'] ?? [];
    $guard = pazar_guard_listing_catalog_write($categoryId, is_array($attributes) ? $attributes : [], is_array($transactionModes) ? $transactionModes : []);
    if ($guard instanceof \Illuminate\Http\JsonResponse) {
        return $guard;
    }
    $attributes = $guard['attributes'] ?? [];
    $requestedModes = $guard['transaction_modes'];
    $normalizedLocation = pazar_listing_validate_location_by_scope($categoryId, $validated['location'] ?? null);
    if ($normalizedLocation instanceof \Illuminate\Http\JsonResponse) {
        return $normalizedLocation;
    }
    
    // listings.world is the H-OS world key for Pazar listings.
    // Pazar is the Marketplace world, so listings in this service are always marketplace-scoped.
    $world = 'marketplace';
    
    // Create listing as DRAFT
    $listingId = \Illuminate\Support\Str::uuid()->toString();
    $priceAmount = array_key_exists('price_amount', $validated) ? $validated['price_amount'] : null;
    $currency = pazar_listing_write_normalize_currency($validated['currency'] ?? null);
    
    $insert = [
        'id' => $listingId,
        'tenant_id' => $tenantId,
        'world' => $world,
        'category_id' => $categoryId,
        'title' => $validated['title'],
        'description' => $validated['description'] ?? null,
        'price_amount' => $priceAmount,
        'currency' => $currency,
        'transaction_modes_json' => json_encode($requestedModes),
        'attributes_json' => !empty($attributes) ? json_encode($attributes) : null,
        'status' => 'draft',
        'created_at' => now(),
        'updated_at' => now()
    ];

    $locationUpdates = pazar_listing_location_column_updates($categoryId, $normalizedLocation);
    foreach ($locationUpdates as $k => $v) {
        $insert[$k] = $v;
    }

    DB::transaction(function () use ($insert, $listingId, $normalizedLocation) {
        DB::table('listings')->insert($insert);
        pazar_listing_sync_service_areas($listingId, $normalizedLocation);
    });
    
    $created = DB::table('listings')->where('id', $listingId)->first();
    return response()->json(pazar_listing_write_response($created), 201);
});

// PATCH /v1/listings/{id} - Update listing (v1: base fields only)
$updateListingMiddleware = [\App\Http\Middleware\PersonaScope::class . ':store'];
$updateListingMiddleware[] = 'auth.any';
$updateListingMiddleware[] = 'auth.ctx';
$updateListingMiddleware[] = 'tenant.scope';
Route::middleware($updateListingMiddleware)->patch('/v1/listings/{id}', function ($id, \Illuminate\Http\Request $request) {
    $tenantId = pazar_listing_write_tenant_id_or_error($request);
    if ($tenantId instanceof \Illuminate\Http\JsonResponse) return $tenantId;

    $listing = pazar_listing_write_owned_listing_or_error((string) $id, (string) $tenantId);
    if ($listing instanceof \Illuminate\Http\JsonResponse) return $listing;

    $validated = $request->validate([
        'title' => 'sometimes|required|string|max:120',
        'description' => 'sometimes|nullable|string',
        'price_amount' => 'sometimes|nullable|integer|min:0',
        'currency' => 'sometimes|nullable|string|size:3',
        'attributes' => 'sometimes|nullable|array',
        'location' => 'sometimes|nullable|array',
    ]);

    if (empty($validated)) {
        return response()->json([
            'error' => 'validation_error',
            'message' => 'At least one editable field is required'
        ], 422);
    }

    $updates = [];

    if (array_key_exists('title', $validated)) {
        $updates['title'] = $validated['title'];
    }
    if (array_key_exists('description', $validated)) {
        $updates['description'] = $validated['description'];
    }
    if (array_key_exists('price_amount', $validated)) {
        $updates['price_amount'] = $validated['price_amount'];
    }
    if (array_key_exists('currency', $validated)) {
        $updates['currency'] = pazar_listing_write_normalize_currency($validated['currency']);
    }
    if (array_key_exists('attributes', $validated)) {
        $transactionModes = $listing->transaction_modes_json ? json_decode($listing->transaction_modes_json, true) : [];
        $attributes = $validated['attributes'] ?? [];
        $guard = pazar_guard_listing_catalog_write(
            (int) $listing->category_id,
            is_array($attributes) ? $attributes : [],
            is_array($transactionModes) ? $transactionModes : []
        );
        if ($guard instanceof \Illuminate\Http\JsonResponse) {
            return $guard;
        }
        $updates['attributes_json'] = !empty($guard['attributes']) ? json_encode($guard['attributes']) : null;
    }
    $normalizedLocation = null;
    if (array_key_exists('location', $validated)) {
        $normalizedLocation = pazar_listing_validate_location_by_scope((int) $listing->category_id, $validated['location']);
        if ($normalizedLocation instanceof \Illuminate\Http\JsonResponse) {
            return $normalizedLocation;
        }
        $locationUpdates = pazar_listing_location_column_updates((int) $listing->category_id, $normalizedLocation);
        foreach ($locationUpdates as $k => $v) {
            $updates[$k] = $v;
        }
    }

    $updates['updated_at'] = now();

    DB::transaction(function () use ($listing, $updates, $validated, $normalizedLocation) {
        DB::table('listings')
            ->where('id', $listing->id)
            ->update($updates);
        if (array_key_exists('location', $validated)) {
            pazar_listing_sync_service_areas((string) $listing->id, $normalizedLocation);
        }
    });

    $updated = DB::table('listings')->where('id', $listing->id)->first();
    return response()->json(pazar_listing_write_response($updated));
});

// POST /v1/listings/{id}/publish - Publish listing
// WP-8: STORE persona requires X-Active-Tenant-Id header (persona.scope:store)
// WP-26: Tenant scope enforced via tenant.scope middleware
// WP-29: Auth required via auth.any middleware
// WP-50: AuthAny middleware validates JWT tokens
// WP-48: Use full class name to avoid Laravel terminate phase alias resolution issue
$publishListingMiddleware = [\App\Http\Middleware\PersonaScope::class . ':store'];
$publishListingMiddleware[] = 'auth.any';
$publishListingMiddleware[] = 'auth.ctx';
$publishListingMiddleware[] = 'tenant.scope';
Route::middleware($publishListingMiddleware)->post('/v1/listings/{id}/publish', function ($id, \Illuminate\Http\Request $request) {
    $tenantId = pazar_listing_write_tenant_id_or_error($request);
    if ($tenantId instanceof \Illuminate\Http\JsonResponse) return $tenantId;

    $listing = pazar_listing_write_owned_listing_or_error((string) $id, (string) $tenantId);
    if ($listing instanceof \Illuminate\Http\JsonResponse) return $listing;
    
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
    
    return response()->json(pazar_listing_write_response($updated));
});
