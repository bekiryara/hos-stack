<?php

namespace App\Http\Controllers\Api\Commerce;

use App\Http\Controllers\Controller;
use App\Models\Listing;
use App\Support\Api\Cursor;
use App\Support\Api\ListingQuery;
use App\Support\Api\ListingReadDTO;
use App\Support\ApiSpine\ListingWriteModel;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;

/**
 * Commerce Listing Controller (API Spine - Read/Write-Path)
 * 
 * Canonical Product API spine for commerce listings.
 * GET endpoints return real data (tenant-scoped); write endpoints return deterministic envelopes.
 */
final class ListingController extends Controller
{
    /**
     * List commerce listings (tenant-scoped)
     * 
     * GET /api/v1/commerce/listings
     */
    public function index(Request $request): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to commerce; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume commerce (should not happen, but safe fallback)
            $worldId = 'commerce';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'commerce') {
            // Mismatch protection: if world is set but not commerce, return error
            return $this->worldContextInvalid($request);
        }

        // Validate cursor (if provided)
        $cursorStr = $request->input('cursor');
        if (!empty($cursorStr) && !Cursor::isValid($cursorStr)) {
            return $this->invalidCursor($request);
        }

        // Build base query (tenant-scoped, world-scoped)
        $query = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('commerce');

        // Apply filters and ordering via ListingQuery
        [$query, $limit, $nextCursorFromQuery] = ListingQuery::apply($query, $request);

        // Get items (limit + 1 to check if there's more)
        $items = $query->limit($limit + 1)->get();
        $hasMore = $items->count() > $limit;
        
        if ($hasMore) {
            $items = $items->take($limit);
        }

        // Build next cursor (from last item)
        $nextCursor = null;
        if ($hasMore && $items->count() > 0) {
            $lastItem = $items->last();
            $afterValue = $lastItem->created_at->toIso8601String() . ':' . $lastItem->id;
            $nextCursor = Cursor::encode('created_at', 'desc', $afterValue);
        }

        // Format response using ListingReadDTO
        $formattedItems = $items->map(function ($item) {
            return ListingReadDTO::fromModel($item);
        })->toArray();

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'items' => $formattedItems,
            'cursor' => [
                'next' => $nextCursor,
            ],
            'meta' => [
                'limit' => $limit,
            ],
            'request_id' => $requestId,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Show commerce listing (tenant-scoped)
     * 
     * GET /api/v1/commerce/listings/{id}
     */
    public function show(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to commerce; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume commerce (should not happen, but safe fallback)
            $worldId = 'commerce';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'commerce') {
            // Mismatch protection: if world is set but not commerce, return error
            return $this->worldContextInvalid($request);
        }

        // Find listing (tenant-scoped, world-scoped)
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('commerce')
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
     * Create commerce listing
     * 
     * POST /api/v1/commerce/listings
     */
    public function store(Request $request): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to commerce; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume commerce (should not happen, but safe fallback)
            $worldId = 'commerce';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'commerce') {
            // Mismatch protection: if world is set but not commerce, return error
            return $this->worldContextInvalid($request);
        }

        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        try {
            // Create listing using ListingWriteModel
            $listing = ListingWriteModel::create($worldId, $tenantId, $request->all());

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
     * Update commerce listing (SPINE_READY - 202 ACCEPTED, no persistence)
     * 
     * PATCH /api/v1/commerce/listings/{id}
     */
    public function update(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to commerce; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume commerce (should not happen, but safe fallback)
            $worldId = 'commerce';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'commerce') {
            // Mismatch protection: if world is set but not commerce, return error
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
     * Delete commerce listing (hard delete)
     * 
     * DELETE /api/v1/commerce/listings/{id}
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (defensive: if ctx.world missing, default to commerce; if present and mismatch, error)
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId)) {
            // Defensive default: if world.lock middleware didn't run, assume commerce (should not happen, but safe fallback)
            $worldId = 'commerce';
            $request->attributes->set('ctx.world', $worldId);
        } elseif ($worldId !== 'commerce') {
            // Mismatch protection: if world is set but not commerce, return error
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
