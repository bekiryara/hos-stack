<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Product Model
 * 
 * Canonical Product model for all worlds (commerce, food, rentals, future worlds).
 * Tenant-scoped, world-specific, type-based (listing/product/service etc).
 */
final class Product extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     */
    protected $table = 'products';

    /**
     * The attributes that are mass assignable.
     * tenant_id is NOT in fillable to prevent cross-tenant leakage (must be set explicitly).
     */
    protected $fillable = [
        'world',
        'type',
        'title',
        'status',
        'currency',
        'price_amount',
        'payload_json',
    ];

    /**
     * The attributes that are guarded (cannot be mass-assigned).
     * tenant_id is guarded to prevent cross-tenant leakage.
     */
    protected $guarded = [
        'tenant_id',
    ];

    /**
     * The attributes that should be cast.
     */
    protected $casts = [
        'tenant_id' => 'integer',
        'price_amount' => 'integer',
        'payload_json' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Scope: Filter by tenant (tenant boundary enforcement)
     */
    public function scopeForTenant($query, $tenantId)
    {
        return $query->where('tenant_id', $tenantId);
    }

    /**
     * Scope: Filter by world (world boundary enforcement)
     */
    public function scopeForWorld($query, $world)
    {
        return $query->where('world', $world);
    }

    /**
     * Scope: Filter by status
     */
    public function scopeForStatus($query, $status)
    {
        return $query->where('status', $status);
    }
}

