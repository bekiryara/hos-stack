<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Listing Model
 * 
 * Represents a listing in enabled worlds (commerce, food, rentals).
 * Tenant-scoped, world-specific, status-based (draft|published).
 */
final class Listing extends Model
{
    use HasFactory, HasUuids;

    /**
     * The table associated with the model.
     */
    protected $table = 'listings';

    /**
     * The primary key type.
     */
    protected $keyType = 'string';

    /**
     * Indicates if the IDs are auto-incrementing.
     */
    public $incrementing = false;

    /**
     * The attributes that are mass assignable.
     */
    protected $fillable = [
        'tenant_id',
        'world',
        'title',
        'description',
        'price_amount',
        'currency',
        'status',
    ];

    /**
     * The attributes that should be cast.
     */
    protected $casts = [
        'price_amount' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Allowed world values
     */
    public const WORLDS = ['commerce', 'food', 'rentals'];

    /**
     * Allowed status values
     */
    public const STATUS_DRAFT = 'draft';
    public const STATUS_PUBLISHED = 'published';

    public const STATUSES = [
        self::STATUS_DRAFT,
        self::STATUS_PUBLISHED,
    ];

    /**
     * Check if listing is published
     */
    public function isPublished(): bool
    {
        return $this->status === self::STATUS_PUBLISHED;
    }

    /**
     * Check if listing is draft
     */
    public function isDraft(): bool
    {
        return $this->status === self::STATUS_DRAFT;
    }

    /**
     * Scope: published listings
     */
    public function scopePublished($query)
    {
        return $query->where('status', self::STATUS_PUBLISHED);
    }

    /**
     * Scope: draft listings
     */
    public function scopeDraft($query)
    {
        return $query->where('status', self::STATUS_DRAFT);
    }

    /**
     * Scope: tenant-scoped
     */
    public function scopeForTenant($query, string $tenantId)
    {
        return $query->where('tenant_id', $tenantId);
    }

    /**
     * Scope: world-scoped
     */
    public function scopeForWorld($query, string $world)
    {
        return $query->where('world', $world);
    }

    /**
     * Scope: public visible (published listings)
     */
    public function scopePublicVisible($query)
    {
        return $query->where('status', self::STATUS_PUBLISHED);
    }
}

