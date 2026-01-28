<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// GET /v1/listings - Search listings
// WP-8: GUEST+ persona (no headers required for basic search, store scope requires X-Active-Tenant-Id)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/listings', function (\Illuminate\Http\Request $request) {
    $query = DB::table('listings');
    
    // WP-FINAL: Validate category_id if provided (fail-fast)
    if ($request->has('category_id')) {
        $categoryId = (int) $request->input('category_id');
        $exists = DB::table('categories')
            ->where('id', $categoryId)
            ->where('status', 'active')
            ->exists();
        if (!$exists) {
            return response()->json([
                'error' => 'category_not_found',
                'message' => "Category with id {$categoryId} not found",
            ], 404);
        }
    }

    // Filter by category_id if provided (WP-48: recursive - include all descendant categories)
    // WP-73: Use CTE subquery in SQL instead of building ID array in PHP
    if ($request->has('category_id')) {
        $categoryId = (int) $request->input('category_id');
        $cteData = pazar_category_descendant_cte_in_clause_sql($categoryId);
        $query->whereRaw("category_id IN " . $cteData['sql'], $cteData['bindings']);
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
    
    // WP-FINAL: Category -> Catalog -> Listing separation (whitelist)
    // If category_id is provided, only allow filter keys that exist in category_filter_schema
    // for that category OR any of its descendants (same CTE used for listings category filter).
    $allowedFilterKeys = null;
    if ($request->has('category_id') && ($request->has('filters') || $request->has('attrs'))) {
        $rootCategoryId = (int) $request->input('category_id');
        $cteData = pazar_category_descendant_cte_in_clause_sql($rootCategoryId);
        $allowedFilterKeys = DB::table('category_filter_schema')
            ->whereRaw("category_id IN " . $cteData['sql'], $cteData['bindings'])
            ->where('status', 'active')
            ->distinct()
            ->pluck('attribute_key')
            ->map(function ($k) { return (string) $k; })
            ->values()
            ->all();
        
        $allowedSet = [];
        foreach ($allowedFilterKeys as $k) { $allowedSet[$k] = true; }
        
        $unknownKeys = [];
        
        if ($request->has('filters')) {
            $incoming = $request->input('filters');
            if (is_array($incoming)) {
                foreach ($incoming as $key => $value) {
                    if (!is_string($key) || $key === '') continue;
                    if (!isset($allowedSet[$key])) {
                        $unknownKeys[] = $key;
                    }
                }
            }
        } elseif ($request->has('attrs')) {
            $incoming = $request->input('attrs');
            if (is_array($incoming)) {
                foreach ($incoming as $key => $value) {
                    if (!is_string($key) || $key === '') continue;
                    // attrs supports *_min/*_max keys; whitelist is based on base key
                    $baseKey = $key;
                    if (preg_match('/^(.*)_(min|max)$/', $key, $m)) {
                        $baseKey = $m[1];
                    }
                    if (!isset($allowedSet[$baseKey])) {
                        $unknownKeys[] = $baseKey;
                    }
                }
            }
        }
        
        $unknownKeys = array_values(array_unique($unknownKeys));
        if (!empty($unknownKeys)) {
            return response()->json([
                'error' => 'VALIDATION_ERROR',
                'message' => 'Unknown filter keys for this category (allowed keys are defined by catalog)',
                'unknown_keys' => $unknownKeys,
            ], 422);
        }
    }

    // WP-75: SPEC-aligned listing filters parsing
    // Primary: filters[...] (SPEC) e.g. filters[capacity_max][min]=100, filters[city]=izmir
    // Secondary: attrs[...] (backward compatible) e.g. attrs[capacity_max_min]=100, attrs[city]=izmir
    if ($request->has('filters')) {
        $filters = $request->input('filters');
        if (is_array($filters)) {
            foreach ($filters as $key => $value) {
                if (!is_string($key) || $key === '') continue;
                if (is_array($value)) {
                    if (array_key_exists('min', $value) && $value['min'] !== null && $value['min'] !== '') {
                        $query->whereRaw("CAST(attributes_json->>? AS INTEGER) >= ?", [$key, (int) $value['min']]);
                    }
                    if (array_key_exists('max', $value) && $value['max'] !== null && $value['max'] !== '') {
                        $query->whereRaw("CAST(attributes_json->>? AS INTEGER) <= ?", [$key, (int) $value['max']]);
                    }
                } else {
                    if ($value === null || $value === '') continue;
                    $query->whereRaw("attributes_json->>? = ?", [$key, $value]);
                }
            }
        }
    } elseif ($request->has('attrs')) {
        // Backward compatible attribute filtering (supports exact match + _min/_max numeric ranges)
        $attrs = $request->input('attrs');
        if (is_array($attrs)) {
            foreach ($attrs as $key => $value) {
                // Range helpers (schema-driven UI uses *_min/*_max keys)
                if (is_string($key) && preg_match('/^(.*)_(min|max)$/', $key, $m)) {
                    $baseKey = $m[1];
                    $rangeType = $m[2]; // min|max
                    if ($rangeType === 'min') {
                        $query->whereRaw("CAST(attributes_json->>? AS INTEGER) >= ?", [$baseKey, (int) $value]);
                    } else {
                        $query->whereRaw("CAST(attributes_json->>? AS INTEGER) <= ?", [$baseKey, (int) $value]);
                    }
                } else {
                    $query->whereRaw("attributes_json->>? = ?", [$key, $value]);
                }
            }
        }
    }
    
    // WP-12: Pagination (per_page default 20, max 50)
    $page = max(1, (int)$request->input('page', 1));
    $perPage = min(50, max(1, (int)$request->input('per_page', 20)));
    $offset = ($page - 1) * $perPage;
    
    // A) Removed unused $total count (response is array, not paginated envelope)
    // Contract: GET /v1/listings returns JSON array (WP-3.1)
    
    // Deterministic ordering
    $listings = $query->orderBy('created_at', 'desc')->orderBy('id', 'desc')
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
// WP-8: GUEST+ persona (no headers required)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/listings/{id}', function ($id) {
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
