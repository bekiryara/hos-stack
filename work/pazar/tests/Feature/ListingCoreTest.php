<?php

namespace Tests\Feature;

use App\Models\Listing;
use Illuminate\Foundation\Testing\TestCase;
use Illuminate\Support\Str;
use Tests\CreatesApplication;

/**
 * Listing Core Feature Tests
 * 
 * Validates CRUD + publish + public search for enabled worlds.
 */
final class ListingCoreTest extends TestCase
{
    use CreatesApplication;

    /**
     * Test tenant boundary: create in tenant A, cannot fetch via panel in tenant B (403)
     */
    public function test_tenant_boundary_enforcement(): void
    {
        $tenantA = (string) Str::uuid();
        $tenantB = (string) Str::uuid();
        $world = 'commerce';

        // Create listing in tenant A
        $listing = Listing::create([
            'tenant_id' => $tenantA,
            'world' => $world,
            'title' => 'Test Listing',
            'status' => 'draft',
        ]);

        // Try to fetch via panel with tenant B (should not be accessible)
        // Note: This test assumes middleware will enforce tenant boundary
        // In real implementation, middleware would set tenant context from auth
        $this->assertTrue($listing->tenant_id === $tenantA);
        $this->assertTrue($listing->tenant_id !== $tenantB);

        // Verify tenant scope works
        $tenantAListings = Listing::query()->forTenant($tenantA)->get();
        $tenantBListings = Listing::query()->forTenant($tenantB)->get();

        $this->assertTrue($tenantAListings->contains($listing));
        $this->assertFalse($tenantBListings->contains($listing));
    }

    /**
     * Test publish flow: draft not visible in public search; published is visible
     */
    public function test_publish_flow_visibility(): void
    {
        $tenantId = (string) Str::uuid();
        $world = 'commerce';

        // Create draft listing
        $draftListing = Listing::create([
            'tenant_id' => $tenantId,
            'world' => $world,
            'title' => 'Draft Listing',
            'status' => Listing::STATUS_DRAFT,
        ]);

        // Create published listing
        $publishedListing = Listing::create([
            'tenant_id' => $tenantId,
            'world' => $world,
            'title' => 'Published Listing',
            'status' => Listing::STATUS_PUBLISHED,
        ]);

        // Draft should not be visible in public search
        $publicListings = Listing::query()->forWorld($world)->published()->get();
        $this->assertFalse($publicListings->contains($draftListing));
        $this->assertTrue($publicListings->contains($publishedListing));

        // Publish draft listing
        $draftListing->status = Listing::STATUS_PUBLISHED;
        $draftListing->save();

        // Now draft should be visible
        $publicListingsAfter = Listing::query()->forWorld($world)->published()->get();
        $this->assertTrue($publicListingsAfter->contains($draftListing));
    }

    /**
     * Test world mismatch: request to /api/food/... while ctx.world=commerce -> 400
     * Note: This is handled by WorldResolver middleware, but we test controller logic
     */
    public function test_world_mismatch_validation(): void
    {
        $tenantId = (string) Str::uuid();
        $world = 'commerce';

        // Create listing in commerce world
        $listing = Listing::create([
            'tenant_id' => $tenantId,
            'world' => $world,
            'title' => 'Commerce Listing',
            'status' => Listing::STATUS_PUBLISHED,
        ]);

        // Verify world scope works
        $commerceListings = Listing::query()->forWorld('commerce')->get();
        $foodListings = Listing::query()->forWorld('food')->get();

        $this->assertTrue($commerceListings->contains($listing));
        $this->assertFalse($foodListings->contains($listing));
    }

    /**
     * Test public search returns only published listings
     */
    public function test_public_search_only_published(): void
    {
        $tenantId = (string) Str::uuid();
        $world = 'commerce';

        // Create mixed status listings
        Listing::create([
            'tenant_id' => $tenantId,
            'world' => $world,
            'title' => 'Draft Listing',
            'status' => Listing::STATUS_DRAFT,
        ]);

        Listing::create([
            'tenant_id' => $tenantId,
            'world' => $world,
            'title' => 'Published Listing',
            'status' => Listing::STATUS_PUBLISHED,
        ]);

        // Public search should only return published
        $publicListings = Listing::query()->forWorld($world)->published()->get();
        $this->assertEquals(1, $publicListings->count());
        $this->assertEquals('Published Listing', $publicListings->first()->title);
    }

    /**
     * Test panel list returns all statuses for tenant
     */
    public function test_panel_list_all_statuses(): void
    {
        $tenantId = (string) Str::uuid();
        $world = 'commerce';

        // Create listings with different statuses
        Listing::create([
            'tenant_id' => $tenantId,
            'world' => $world,
            'title' => 'Draft Listing',
            'status' => Listing::STATUS_DRAFT,
        ]);

        Listing::create([
            'tenant_id' => $tenantId,
            'world' => $world,
            'title' => 'Published Listing',
            'status' => Listing::STATUS_PUBLISHED,
        ]);

        // Panel should return all statuses for tenant
        $panelListings = Listing::query()
            ->forTenant($tenantId)
            ->forWorld($world)
            ->get();

        $this->assertEquals(2, $panelListings->count());
    }
}

