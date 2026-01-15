<?php

namespace Tests\Feature\Api;

use Illuminate\Foundation\Testing\TestCase;
use Tests\CreatesApplication;

/**
 * Commerce Listing API Spine Feature Tests
 * 
 * Validates API spine contract: routes exist, auth required, error envelope compliance.
 */
final class CommerceListingSpineTest extends TestCase
{
    use CreatesApplication;

    /**
     * Test unauthorized GET /api/v1/commerce/listings returns 401/403 with standard envelope and request_id
     */
    public function test_unauthorized_get_listings_returns_401_or_403_with_envelope(): void
    {
        $response = $this->get('/api/v1/commerce/listings', [
            'Accept' => 'application/json',
        ]);

        // Accept 401 or 403 (both indicate auth required)
        $this->assertTrue($response->status() === 401 || $response->status() === 403);

        $json = $response->json();

        // Validate standard error envelope
        $this->assertIsArray($json);
        $this->assertFalse($json['ok'] ?? true);
        $this->assertNotEmpty($json['error_code'] ?? null);
        $this->assertNotEmpty($json['request_id'] ?? null);

        // Validate X-Request-Id header matches body request_id
        $headerRequestId = $response->headers->get('X-Request-Id');
        if ($headerRequestId !== null) {
            $this->assertEquals($json['request_id'], $headerRequestId);
        }

        // Ensure request_id is non-empty
        $this->assertNotEmpty($json['request_id']);
    }

    /**
     * Test unauthorized POST /api/v1/commerce/listings returns 401/403 with standard envelope and request_id
     */
    public function test_unauthorized_post_listings_returns_401_or_403_with_envelope(): void
    {
        $response = $this->post('/api/v1/commerce/listings', [], [
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ]);

        // Accept 401 or 403 (both indicate auth required)
        $this->assertTrue($response->status() === 401 || $response->status() === 403);

        $json = $response->json();

        // Validate standard error envelope
        $this->assertIsArray($json);
        $this->assertFalse($json['ok'] ?? true);
        $this->assertNotEmpty($json['error_code'] ?? null);
        $this->assertNotEmpty($json['request_id'] ?? null);

        // Validate X-Request-Id header matches body request_id
        $headerRequestId = $response->headers->get('X-Request-Id');
        if ($headerRequestId !== null) {
            $this->assertEquals($json['request_id'], $headerRequestId);
        }

        // Ensure request_id is non-empty
        $this->assertNotEmpty($json['request_id']);
    }
}





