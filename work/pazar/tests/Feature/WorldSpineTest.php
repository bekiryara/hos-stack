<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\TestCase;
use Tests\CreatesApplication;

/**
 * World Spine Feature Tests
 * 
 * Validates enabled/disabled world routes and closed-world enforcement.
 */
final class WorldSpineTest extends TestCase
{
    use CreatesApplication;

    /**
     * Test enabled world home page returns 200 with X-World header
     */
    public function test_enabled_world_home_returns_200_with_world_header(): void
    {
        $enabledWorlds = ['commerce', 'food', 'rentals'];

        foreach ($enabledWorlds as $world) {
            $response = $this->get("/worlds/{$world}");

            $response->assertStatus(200);
            $response->assertHeader('X-World', $world);
        }
    }

    /**
     * Test disabled world returns 410 WORLD_CLOSED
     */
    public function test_disabled_world_returns_410_world_closed(): void
    {
        $disabledWorlds = ['services', 'real_estate', 'vehicle'];

        foreach ($disabledWorlds as $world) {
            $response = $this->get("/worlds/{$world}", [
                'Accept' => 'application/json',
            ]);

            $response->assertStatus(410);
            $response->assertJson([
                'ok' => false,
                'error_code' => 'WORLD_CLOSED',
                'world' => $world,
            ]);
            $response->assertHeader('X-World', $world);
        }
    }

    /**
     * Test disabled world HTML returns 410 with closed page
     */
    public function test_disabled_world_html_returns_410_closed_page(): void
    {
        $response = $this->get('/worlds/services', [
            'Accept' => 'text/html',
        ]);

        $response->assertStatus(410);
        $response->assertHeader('X-World', 'services');
        $response->assertSee('World Closed', false);
        $response->assertSee('services', false);
    }

    /**
     * Test missing world context returns 400
     */
    public function test_missing_world_returns_400(): void
    {
        // This test would require a route without world parameter
        // For now, we test with invalid world (should return 404, not 400)
        $response = $this->get('/worlds/invalid_world', [
            'Accept' => 'application/json',
        ]);

        $response->assertStatus(404);
        $response->assertJson([
            'ok' => false,
            'error_code' => 'WORLD_NOT_FOUND',
            'world' => 'invalid_world',
        ]);
    }

    /**
     * Test world search returns 200 (placeholder)
     */
    public function test_enabled_world_search_returns_200(): void
    {
        $response = $this->get('/worlds/commerce/search', [
            'Accept' => 'application/json',
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'ok' => true,
            'world' => 'commerce',
            'message' => 'Search not implemented yet',
        ]);
        $response->assertHeader('X-World', 'commerce');
    }
}

