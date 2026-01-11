<?php

namespace App\Support\ApiSpine;

use Illuminate\Support\Facades\DB;

/**
 * Listing Read Model
 * 
 * Minimal query layer for listing read operations (GET endpoints only).
 * Supports tenant and world scoping via fluent builder pattern.
 * No domain logic, just simple DB queries.
 */
final class ListingReadModel
{
    private ?string $tenantId = null;
    private ?string $world = null;

    /**
     * Scope query to tenant
     * 
     * @param string $tenantId Tenant ID
     * @return self
     */
    public static function forTenant(string $tenantId): self
    {
        $instance = new self();
        $instance->tenantId = $tenantId;
        return $instance;
    }

    /**
     * Scope query to world
     * 
     * @param string $world World ID (commerce|food|rentals)
     * @return self
     */
    public function forWorld(string $world): self
    {
        $this->world = $world;
        return $this;
    }

    /**
     * Get base query with tenant/world scoping applied
     * 
     * @return \Illuminate\Database\Query\Builder
     */
    private function baseQuery()
    {
        $query = DB::table('listings');

        // Apply tenant scope if set
        if ($this->tenantId !== null) {
            $query->where('tenant_id', $this->tenantId);
        }

        // Apply world scope if set
        if ($this->world !== null) {
            $query->where('world', $this->world);
        }

        return $query;
    }

    /**
     * Get index query (tenant-scoped, world-scoped)
     * Returns query builder for index operations (pagination, filtering)
     * 
     * @return \Illuminate\Database\Query\Builder
     */
    public function indexQuery()
    {
        return $this->baseQuery()
            ->where('status', 'published')
            ->orderBy('created_at', 'desc')
            ->orderBy('id', 'desc'); // Secondary sort for cursor stability
    }

    /**
     * List listings (tenant-scoped, world-scoped)
     * 
     * @param int $limit Maximum number of items to return
     * @param int $offset Offset for pagination
     * @return array Array of listing items
     */
    public function list(int $limit = 20, int $offset = 0): array
    {
        $items = $this->indexQuery()
            ->limit($limit)
            ->offset($offset)
            ->get()
            ->map(function ($item) {
                return [
                    'id' => $item->id,
                    'world' => $item->world,
                    'title' => $item->title,
                    'status' => $item->status,
                    'price' => $item->price_amount ? (float) $item->price_amount : null,
                    'currency' => $item->currency,
                    'created_at' => $item->created_at,
                    'updated_at' => $item->updated_at,
                ];
            })
            ->toArray();

        return $items;
    }

    /**
     * Get total count of active listings (tenant-scoped, world-scoped)
     * 
     * @return int Total count
     */
    public function count(): int
    {
        return (int) $this->baseQuery()
            ->where('status', 'published')
            ->count();
    }

    /**
     * Find a single listing by ID (tenant-scoped, world-scoped)
     * 
     * @param string|int $id Listing ID
     * @return array|null Listing item or null if not found
     */
    public function findOne(string|int $id): ?array
    {
        $item = $this->baseQuery()
            ->where('id', $id)
            ->where('status', 'published')
            ->first();

        if (!$item) {
            return null;
        }

        return [
            'id' => $item->id,
            'world' => $item->world,
            'title' => $item->title,
            'status' => $item->status,
            'price' => $item->price_amount ? (float) $item->price_amount : null,
            'currency' => $item->currency,
            'created_at' => $item->created_at,
            'updated_at' => $item->updated_at,
        ];
    }

    /**
     * Find a single listing by ID (tenant-scoped, world-scoped)
     * Alias for findOne() for backward compatibility
     * 
     * @param string $id Listing ID
     * @return array|null Listing item or null if not found
     */
    public function find(string $id): ?array
    {
        return $this->findOne($id);
    }
}

