<?php

namespace App\Http\Controllers\Api\Rentals;

use App\Http\Controllers\Controller;
use App\Models\Listing;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

/**
 * Rentals Listing Controller (API Spine - Read-Path v1)
 * 
 * Canonical Product API spine for rentals listings.
 * GET endpoints return tenant-scoped data; write endpoints return 501 NOT_IMPLEMENTED.
 */
final class ListingController extends Controller
{
    /**
     * List rentals listings (tenant-scoped)
     * 
     * GET /api/v1/rentals/listings
     */
    public function index(Request $request): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId) || $worldId !== 'rentals') {
            return $this->worldContextInvalid($request);
        }

        // Pagination params (deterministic: limit clamp 1..100, default 20)
        $limit = (int) $request->input('limit', 20);
        $limit = min(max($limit, 1), 100); // Clamp between 1 and 100
        $cursor = $request->input('cursor');

        // Query listings (tenant-scoped, world-scoped)
        $query = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('rentals')
            ->orderByDesc('created_at')
            ->orderByDesc('id'); // Secondary sort for cursor stability

        // Cursor pagination (if cursor provided)
        if ($cursor !== null && $cursor !== '') {
            $decoded = base64_decode($cursor, true);
            if ($decoded !== false) {
                $parts = explode(':', $decoded, 2);
                if (count($parts) === 2) {
                    [$cursorCreatedAt, $cursorId] = $parts;
                    $query->where(function ($q) use ($cursorCreatedAt, $cursorId) {
                        $q->where('created_at', '<', $cursorCreatedAt)
                            ->orWhere(function ($q2) use ($cursorCreatedAt, $cursorId) {
                                $q2->where('created_at', '=', $cursorCreatedAt)
                                    ->where('id', '<', $cursorId);
                            });
                    });
                }
            }
        }

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
            $cursorData = $lastItem->created_at->toIso8601String() . ':' . $lastItem->id;
            $nextCursor = base64_encode($cursorData);
        }

        // Format response
        $formattedItems = $items->map(function ($item) {
            return [
                'id' => $item->id,
                'title' => $item->title,
                'description' => $item->description,
                'price_amount' => $item->price_amount,
                'currency' => $item->currency,
                'status' => $item->status,
                'created_at' => $item->created_at?->toIso8601String(),
                'updated_at' => $item->updated_at?->toIso8601String(),
            ];
        })->toArray();

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'data' => [
                'items' => $formattedItems,
                'cursor' => [
                    'next' => $nextCursor,
                ],
                'meta' => [
                    'count' => count($formattedItems),
                    'limit' => $limit,
                ],
            ],
            'request_id' => $requestId,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Show rentals listing (tenant-scoped)
     * 
     * GET /api/v1/rentals/listings/{id}
     */
    public function show(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope
        $worldId = $request->attributes->get('ctx.world');
        if (empty($worldId) || $worldId !== 'rentals') {
            return $this->worldContextInvalid($request);
        }

        // Find listing (tenant-scoped, world-scoped)
        $listing = Listing::query()
            ->forTenant($tenantId)
            ->forWorld('rentals')
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

        // Format item
        $item = [
            'id' => $listing->id,
            'title' => $listing->title,
            'description' => $listing->description,
            'price_amount' => $listing->price_amount,
            'currency' => $listing->currency,
            'status' => $listing->status,
            'created_at' => $listing->created_at?->toIso8601String(),
            'updated_at' => $listing->updated_at?->toIso8601String(),
        ];

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'data' => [
                'item' => $item,
            ],
            'request_id' => $requestId,
        ]);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Create rentals listing (NOT_IMPLEMENTED - 501 stub)
     * 
     * POST /api/v1/rentals/listings
     */
    public function store(Request $request): JsonResponse
    {
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'NOT_IMPLEMENTED',
            'message' => 'Write endpoints are not implemented yet.',
            'request_id' => $requestId,
        ], 501);

        return $response->header('X-Request-Id', $requestId);
    }

    /**
     * Update rentals listing (NOT_IMPLEMENTED - 501 stub)
     * 
     * PATCH /api/v1/rentals/listings/{id}
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'NOT_IMPLEMENTED',
            'message' => 'Write endpoints are not implemented yet.',
            'request_id' => $requestId,
        ], 501);

        return $response->header('X-Request-Id', $requestId);
    }

    /**
     * Delete rentals listing (NOT_IMPLEMENTED - 501 stub)
     * 
     * DELETE /api/v1/rentals/listings/{id}
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'NOT_IMPLEMENTED',
            'message' => 'Write endpoints are not implemented yet.',
            'request_id' => $requestId,
        ], 501);

        return $response->header('X-Request-Id', $requestId);
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
}



