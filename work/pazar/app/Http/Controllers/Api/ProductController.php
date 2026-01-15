<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MetricsController;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Product Controller (API Spine - Read/Create)
 * 
 * Canonical Product API spine for all worlds (commerce, food, rentals, future).
 * Read endpoints: GET /api/v1/products and GET /api/v1/products/{id}
 * Write endpoint: POST /api/v1/products (create-only, update/delete not implemented)
 * World boundary enforced via query param ?world=commerce (read) or X-World header/body.world (write).
 */
final class ProductController extends Controller
{
    /**
     * List products (tenant-scoped, world-locked)
     * 
     * GET /api/v1/products?world=commerce&limit=20&after_id=123
     */
    public function index(Request $request): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (required query param)
        $world = $request->query('world');
        if (empty($world)) {
            // Try X-World header as fallback
            $world = $request->header('X-World');
        }
        
        if (empty($world)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'VALIDATION_ERROR',
                'message' => 'World parameter is required. Use ?world=commerce or X-World header.',
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }

        // Validate world is enabled (optional check, but good practice)
        $enabledWorlds = ['commerce', 'food', 'rentals'];
        if (!in_array($world, $enabledWorlds)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'WORLD_NOT_ENABLED',
                'message' => "World '$world' is not enabled.",
                'request_id' => $requestId,
            ], 400);

            return $response->header('X-Request-Id', $requestId);
        }

        // Pagination
        $limit = (int) $request->query('limit', 20);
        $limit = max(1, min(100, $limit)); // Clamp 1-100

        $afterId = $request->query('after_id');

        // Query products (tenant-scoped, world-scoped)
        $query = Product::query()
            ->forTenant($tenantId)
            ->forWorld($world)
            ->orderBy('id', 'desc');

        if ($afterId) {
            $query->where('id', '<', $afterId);
        }

        $products = $query->limit($limit)->get();

        // Format items
        $formattedItems = $products->map(function ($product) {
            return [
                'id' => $product->id,
                'world' => $product->world,
                'type' => $product->type,
                'title' => $product->title,
                'status' => $product->status,
                'currency' => $product->currency,
                'price_amount' => $product->price_amount,
                'payload_json' => $product->payload_json,
                'created_at' => $product->created_at?->toIso8601String(),
                'updated_at' => $product->updated_at?->toIso8601String(),
            ];
        })->toArray();

        // Next cursor (after_id)
        $nextCursor = null;
        if ($products->count() === $limit && $products->last()) {
            $nextCursor = $products->last()->id;
        }

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
     * Show product (tenant-scoped, world-locked)
     * 
     * GET /api/v1/products/{id}?world=commerce
     */
    public function show(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (required query param)
        $world = $request->query('world');
        if (empty($world)) {
            // Try X-World header as fallback
            $world = $request->header('X-World');
        }
        
        if (empty($world)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'VALIDATION_ERROR',
                'message' => 'World parameter is required. Use ?world=commerce or X-World header.',
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }

        // Validate world is enabled
        $enabledWorlds = ['commerce', 'food', 'rentals'];
        if (!in_array($world, $enabledWorlds)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'WORLD_NOT_ENABLED',
                'message' => "World '$world' is not enabled.",
                'request_id' => $requestId,
            ], 400);

            return $response->header('X-Request-Id', $requestId);
        }

        // Find product (tenant-scoped, world-scoped) - returns 404 if not found (cross-tenant leakage prevented)
        $product = Product::query()
            ->forTenant($tenantId)
            ->forWorld($world)
            ->find($id);

        if (!$product) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Product not found.',
                'request_id' => $requestId,
            ], 404);

            return $response->header('X-Request-Id', $requestId);
        }

        // Format item
        $item = [
            'id' => $product->id,
            'world' => $product->world,
            'type' => $product->type,
            'title' => $product->title,
            'status' => $product->status,
            'currency' => $product->currency,
            'price_amount' => $product->price_amount,
            'payload_json' => $product->payload_json,
            'created_at' => $product->created_at?->toIso8601String(),
            'updated_at' => $product->updated_at?->toIso8601String(),
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
     * Create product (tenant-scoped, world-locked)
     * 
     * POST /api/v1/products
     */
    public function store(Request $request): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (required: X-World header OR body.world)
        $world = $request->header('X-World');
        if (empty($world)) {
            $world = $request->input('world');
        }
        
        if (empty($world)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'VALIDATION_ERROR',
                'message' => 'World is required. Use X-World header or body.world parameter.',
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }

        // Validate world is enabled
        $enabledWorlds = ['commerce', 'food', 'rentals'];
        if (!in_array($world, $enabledWorlds)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'WORLD_CONTEXT_INVALID',
                'message' => "World '$world' is not enabled.",
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }

        // Validate input
        try {
            $validated = $request->validate([
                'title' => 'required|string|min:3|max:255',
                'type' => 'required|string|max:64',
                'status' => 'nullable|string|max:32|in:draft,published,archived',
                'price_amount' => 'nullable|integer|min:0',
                'currency' => 'nullable|string|max:8',
                'payload_json' => 'nullable|array',
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

        // Create product (tenant_id from resolved context, NOT from request body)
        try {
            $product = Product::create([
                'tenant_id' => $tenantId, // Explicitly set from resolved context (guarded, cannot be mass-assigned)
                'world' => $world,
                'type' => $validated['type'],
                'title' => $validated['title'],
                'status' => $validated['status'] ?? 'draft',
                'currency' => $validated['currency'] ?? null,
                'price_amount' => $validated['price_amount'] ?? null,
                'payload_json' => $validated['payload_json'] ?? null,
            ]);
            
            // Increment metrics counter
            MetricsController::incrementProductCreate();
        } catch (\Exception $e) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'INTERNAL_ERROR',
                'message' => 'Failed to create product.',
                'request_id' => $requestId,
            ], 500);

            return $response->header('X-Request-Id', $requestId);
        }

        // Format item
        $item = [
            'id' => $product->id,
            'world' => $product->world,
            'type' => $product->type,
            'title' => $product->title,
            'status' => $product->status,
            'currency' => $product->currency,
            'price_amount' => $product->price_amount,
            'payload_json' => $product->payload_json,
            'created_at' => $product->created_at?->toIso8601String(),
            'updated_at' => $product->updated_at?->toIso8601String(),
        ];

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'data' => [
                'item' => $item,
                'id' => $product->id,
            ],
            'request_id' => $requestId,
        ], 201);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }

    /**
     * Disable product (soft delete, tenant-scoped, world-locked)
     * 
     * PATCH /api/v1/products/{id}/disable
     */
    public function disable(Request $request, string $id): JsonResponse
    {
        // Resolve tenant context
        $tenantId = $this->resolveTenantId($request);
        if (empty($tenantId)) {
            return $this->tenantContextMissing($request);
        }

        // Enforce world scope (required query param)
        $world = $request->query('world');
        if (empty($world)) {
            // Try X-World header as fallback
            $world = $request->header('X-World');
        }
        
        if (empty($world)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'VALIDATION_ERROR',
                'message' => 'World parameter is required. Use ?world=commerce or X-World header.',
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }

        // Validate world is enabled
        $enabledWorlds = ['commerce', 'food', 'rentals'];
        if (!in_array($world, $enabledWorlds)) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'WORLD_CONTEXT_INVALID',
                'message' => "World '$world' is not enabled.",
                'request_id' => $requestId,
            ], 422);

            return $response->header('X-Request-Id', $requestId);
        }

        // Find product (tenant-scoped, world-scoped) - returns 404 if not found (cross-tenant leakage prevented)
        $product = Product::query()
            ->forTenant($tenantId)
            ->forWorld($world)
            ->find($id);

        if (!$product) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Product not found.',
                'request_id' => $requestId,
            ], 404);

            return $response->header('X-Request-Id', $requestId);
        }

        // Soft disable (idempotent: if already archived, return success)
        try {
            if ($product->status !== 'archived') {
                $product->status = 'archived';
                $product->save();
                
                // Increment metrics counter
                MetricsController::incrementProductDisable();
            }
        } catch (\Exception $e) {
            $requestId = $request->attributes->get('request_id', '');
            if (empty($requestId)) {
                $requestId = (string) Str::uuid();
            }

            $response = response()->json([
                'ok' => false,
                'error_code' => 'INTERNAL_ERROR',
                'message' => 'Failed to disable product.',
                'request_id' => $requestId,
            ], 500);

            return $response->header('X-Request-Id', $requestId);
        }

        // Format item
        $item = [
            'id' => $product->id,
            'world' => $product->world,
            'type' => $product->type,
            'title' => $product->title,
            'status' => $product->status,
            'currency' => $product->currency,
            'price_amount' => $product->price_amount,
            'payload_json' => $product->payload_json,
            'created_at' => $product->created_at?->toIso8601String(),
            'updated_at' => $product->updated_at?->toIso8601String(),
        ];

        $requestId = $request->attributes->get('request_id', '');

        $response = response()->json([
            'ok' => true,
            'data' => [
                'item' => $item,
            ],
            'request_id' => $requestId,
        ], 200);

        if ($requestId !== '') {
            $response->header('X-Request-Id', $requestId);
        }

        return $response;
    }
}

