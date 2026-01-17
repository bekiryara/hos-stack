<?php

namespace App\Core;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Core Membership Client (WP-8)
 * Validates membership via Core API calls (no direct DB access).
 */
class MembershipClient
{
    private $baseUrl;
    private $timeout;

    public function __construct()
    {
        // Core API base URL (default: internal docker DNS)
        $this->baseUrl = env('HOS_API_BASE_URL', 'http://hos-api:3000');
        $this->timeout = (int) env('HOS_API_TIMEOUT', 2); // 2 seconds timeout (non-fatal)
    }

    /**
     * Validate tenant membership for a user via HOS API (WP-8 Strict Mode).
     * 
     * @param string $tenantId Tenant ID (from X-Active-Tenant-Id header)
     * @param string $authToken Authorization Bearer token (from request header)
     * @return array|null Returns ['allowed' => bool, 'role' => string|null, 'status' => string|null] or null on error
     */
    public function checkMembershipViaHos($tenantId, $authToken): ?array
    {
        if (empty($tenantId) || empty($authToken)) {
            return null;
        }

        // Validate UUID format
        if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $tenantId)) {
            return null;
        }

        try {
            $response = Http::timeout($this->timeout)
                ->withHeaders([
                    'Authorization' => $authToken,
                    'Content-Type' => 'application/json'
                ])
                ->get("{$this->baseUrl}/v1/tenants/{$tenantId}/memberships/me");

            if ($response->successful()) {
                $data = $response->json();
                return [
                    'allowed' => $data['allowed'] ?? false,
                    'role' => $data['role'] ?? null,
                    'status' => $data['status'] ?? null
                ];
            }

            Log::warning('hos.membership_check.failed', [
                'tenant_id' => $tenantId,
                'status' => $response->status(),
                'body' => $response->body()
            ]);

            return null;
        } catch (\Exception $e) {
            Log::warning('hos.membership_check.exception', [
                'tenant_id' => $tenantId,
                'error' => $e->getMessage()
            ]);

            return null;
        }
    }

    /**
     * Validate tenant membership for a user (GENESIS: simplified validation).
     * 
     * In GENESIS phase: validates that tenant_id exists and has valid format.
     * Strict mode: calls HOS API to verify active membership.
     * 
     * @param string $userId User ID (from JWT token sub claim, or genesis-default for backward compatibility)
     * @param string $tenantId Tenant ID (from X-Active-Tenant-Id header)
     * @param string|null $authToken Authorization token (for strict mode)
     * @return bool True if membership is valid (or validation skipped in GENESIS), false otherwise
     */
    public function validateMembership($userId, $tenantId, $authToken = null): bool
    {
        // Check strict mode flag
        $strictMode = env('MARKETPLACE_MEMBERSHIP_STRICT', 'off') === 'on';
        
        if ($strictMode && $authToken) {
            // Strict mode: verify via HOS API
            $result = $this->checkMembershipViaHos($tenantId, $authToken);
            return $result !== null && $result['allowed'] === true;
        }

        // Non-strict mode: format validation only (backward compatible)
        if (empty($tenantId)) {
            return false;
        }

        // Validate UUID format
        if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $tenantId)) {
            return false;
        }

        // In GENESIS phase: assume valid if format is correct
        return true;
    }

    /**
     * Check if tenant ID has valid format (helper for validation).
     * 
     * @param string $tenantId Tenant ID
     * @return bool True if format is valid
     */
    public function isValidTenantIdFormat($tenantId): bool
    {
        if (empty($tenantId)) {
            return false;
        }

        // UUID format validation
        return preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $tenantId) === 1;
    }
}


