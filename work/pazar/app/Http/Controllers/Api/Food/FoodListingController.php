<?php

namespace App\Http\Controllers\Api\Food;

use App\Http\Controllers\Controller;
use App\Models\Listing;
use App\Support\Api\ListingReadDTO;
use App\Support\ApiSpine\ListingQueryModel;
use App\Support\ApiSpine\ListingWriteModel;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;

/**
 * Food Listing Controller (API Spine - Read-Path v2)
 * 
 * Canonical Product API spine for food listings.
 * GET endpoints return tenant-scoped data; write endpoints return 501 NOT_IMPLEMENTED.
 */
final class FoodListingController extends Controller
{
    /**
     * List food listings (tenant-scoped)
     * 
     * GET /api/v1/food/listings
     */
    public function index(Request $request): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to food; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume food (should not happen, but safe fallback)
            $worldId = 'food';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'food') {
            // Mismatch protection: if world is set but not food, return error
            return $this->worldContextInvalid($request);
        }

        // Validate cursor (if provided)
        $cursorStr = $request->input('cursor');
        if (!empty($cursorStr) && !ListingQueryModel::validateCursor($cursorStr, $tenantId, $worldId)) {
            return ListingQueryModel::invalidCursorResponse($request);
        }

        // Use ListingQueryModel for query execution
        $result = ListingQueryModel::query($tenantId, $worldId, $request);

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'items' => $result['items'],
            'page' => $result['page'],
            'request_id' => $requestId,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Show food listing (tenant-scoped)
     * 
     * GET /api/v1/food/listings/{id}
     */
    public function show(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to food; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume food (should not happen, but safe fallback)
            $worldId = 'food';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'food') {
            // Mismatch protection: if world is set but not food, return error
            return $this->worldContextInvalid($request);
        }

        // Find listing (tenant-scoped, world-scoped)
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('food')
            ->find($id);

        if (!$listing) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Listing not found.',
                'request_id' => $requestId,
            ], 404);

            return $response->header('X-Request-Id', $requestId);
        }

        // Format item using ListingReadDTO
        $item = ListingReadDTO::fromModel($listing);

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'item' => $item,
            'request_id' => $requestId,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Create food listing
     * 
     * POST /api/v1/food/listings
     */
    public function store(Request $request): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to food; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume food (should not happen, but safe fallback)
            $worldId = 'food';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'food') {
            // Mismatch protection: if world is set but not food, return error
            return $this->worldContextInvalid($request);
        }

        // Validate required fields
        try {
            $validated = $request->validate([
                'title' => 'required|string|max:255',
                'price_amount' => 'nullable|integer|min:0',
                'currency' => 'nullable|string|size:3',
                'status' => 'nullable|in:draft,published',
            ]);
        } catch (ValidationException $e) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'VALIDATION_ERROR',
                'message' => 'The given data was invalid.',
                'errors' => $e->errors(),
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }

        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        // Create listing
        $listing = new Listing();
        $listing->tenant_id = $tenantId;
        $listing->world = $worldId;
        $listing->title = $validated['title'];
        $listing->description = $request->input('description');
        
        // Set optional fields only if provided
        if (isset($validated['price_amount'])) {
            $listing->price_amount = $validated['price_amount'];
        }
        if (isset($validated['currency'])) {
            $listing->currency = $validated['currency'];
        }
        if (isset($validated['status'])) {
            $listing->status = $validated['status'];
        } else {
            // Default to draft if status not provided
            $listing->status = 'draft';
        }
        
        $listing->save();

        // Format item using ListingReadDTO
        $item = ListingReadDTO::fromModel($listing);

        // Audit log
        Log::info('Product write path: CREATE_LISTING', [
            'request_id' => $requestId,
            'tenant_id' => $tenantId,
            'world' => $worldId,
            'listing_id' => $listing->id,
            'operation' => 'CREATE_LISTING',
        ]);

        // Return 201 CREATED
        $response = response()->json([
            'ok' => true,
            'item' => $item,
            'request_id' => $requestId,
        ], 201);

        return $response->header('X-Request-Id', $requestId);
    }

    /**
     * Update food listing (partial update)
     * 
     * PATCH /api/v1/food/listings/{id}
     */
    public function update(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to food; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume food (should not happen, but safe fallback)
            $worldId = 'food';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'food') {
            // Mismatch protection: if world is set but not food, return error
            return $this->worldContextInvalid($request);
        }

        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        try {
            // Update listing using ListingWriteModel
            $listing = ListingWriteModel::update($worldId, $tenantId, $id, $request->all());

            if ($listing === null) {
                // Not found in tenant+world scope (404 NOT_FOUND, prevents cross-tenant leakage)
                return $this->notFound($request);
            }

            // Format item using ListingReadDTO
            $item = ListingReadDTO::fromModel($listing);

            // Audit log
            Log::info('Product write path: UPDATE_LISTING', [
                'request_id' => $requestId,
                'tenant_id' => $tenantId,
                'world' => $worldId,
                'listing_id' => $id,
                'operation' => 'UPDATE_LISTING',
            ]);

            // Return 200 OK
            $response = response()->json([
                'ok' => true,
                'item' => $item,
                'request_id' => $requestId,
            ], 200);

            return $response->header('X-Request-Id', $requestId);
        } catch (ValidationException $e) {
            $response = response()->json([
                'ok' => false,
                'error_code' => 'VALIDATION_ERROR',
                'message' => 'The given data was invalid.',
                'errors' => $e->errors(),
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }
    }

    /**
     * Delete food listing (hard delete)
     * 
     * DELETE /api/v1/food/listings/{id}
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to food; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume food (should not happen, but safe fallback)
            $worldId = 'food';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'food') {
            // Mismatch protection: if world is set but not food, return error
            return $this->worldContextInvalid($request);
        }

        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        // Delete listing using ListingWriteModel
        $deleted = ListingWriteModel::delete($worldId, $tenantId, $id);

        if (!$deleted) {
            // Not found in tenant+world scope (404 NOT_FOUND, prevents cross-tenant leakage)
            return $this->notFound($request);
        }

        // Audit log
        Log::info('Product write path: DELETE_LISTING', [
            'request_id' => $requestId,
            'tenant_id' => $tenantId,
            'world' => $worldId,
            'listing_id' => $id,
            'operation' => 'DELETE_LISTING',
        ]);

        // Return 204 NO CONTENT (consistent across all worlds)
        return response()->json([
            'ok' => true,
            'deleted' => true,
            'id' => $id,
            'request_id' => $requestId,
        ], 204)->header('X-Request-Id', $requestId);
    }

    /**
     * Resolve tenant ID from request
     */
    private function resolveTenantId(Request $request): ?string
    {
        // Prefer request attributes (from resolve.tenant middleware)
        $tenantId = $request->attributes->get('tenant_id');
        if ($tenantId !== null && $tenantId !== '') {
            return (string) $tenantId;
        }

        // Try request->tenant property (from middleware)
        if (isset($request->tenant) && is_object($request->tenant) && isset($request->tenant->id)) {
            return (string) $request->tenant->id;
        }

        // Try request attributes with different key
        $tenant = $request->attributes->get('tenant');
        if (is_object($tenant) && isset($tenant->id)) {
            return (string) $tenant->id;
        }

        // Try user tenant_id
        $user = $request->user();
        if ($user && isset($user->tenant_id)) {
            return (string) $user->tenant_id;
        }

        return null;
    }

    /**
     * Tenant context missing error response
     */
    private function tenantContextMissing(Request $request): JsonResponse
    {
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'TENANT_CONTEXT_MISSING',
            'message' => 'Tenant context missing',
            'request_id' => $requestId,
        ], 500);

        return $response->header('X-Request-Id', $requestId);
    }

    /**
     * World context invalid error response
     */
    private function worldContextInvalid(Request $request): JsonResponse
    {
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'WORLD_CONTEXT_INVALID',
            'message' => 'World context invalid or missing',
            'request_id' => $requestId,
        ], 400);

        return $response->header('X-Request-Id', $requestId);
    }

    /**
     * Invalid cursor error response
     */
    private function invalidCursor(Request $request): JsonResponse
    {
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'INVALID_CURSOR',
            'message' => 'Invalid cursor value',
            'request_id' => $requestId,
        ], 400);

        return $response->header('X-Request-Id', $requestId);
    }

    /**
     * Not found error response
     */
    private function notFound(Request $request): JsonResponse
    {
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'NOT_FOUND',
            'message' => 'Listing not found.',
            'request_id' => $requestId,
        ], 404);

        return $response->header('X-Request-Id', $requestId);
    }
}

