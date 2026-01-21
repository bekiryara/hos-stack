<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * AuthContext Middleware (WP-13)
 * Extracts requester_user_id from JWT token (sub claim) instead of X-Requester-User-Id header.
 */
class AuthContext
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Get Authorization header
        $authHeader = $request->header('Authorization');
        
        // WP-13: If Authorization header exists, verify token and extract user ID
        // If no header, continue without setting requester_user_id (for store-scope endpoints)
        if ($authHeader && preg_match('/^Bearer\s+(.+)$/i', $authHeader, $matches)) {
            $token = $matches[1];

            // Get JWT secret from environment
            $jwtSecret = env('HOS_JWT_SECRET') ?: env('JWT_SECRET');
            if (!$jwtSecret || strlen($jwtSecret) < 32) {
                // Only fail if token is provided but secret is missing
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'JWT secret not configured (HOS_JWT_SECRET or JWT_SECRET required)'
                ], 500);
            }

            // Verify JWT token (HS256 algorithm)
            try {
                $payload = $this->verifyJWT($token, $jwtSecret);
            } catch (\Exception $e) {
                return response()->json([
                    'error' => 'AUTH_REQUIRED',
                    'message' => 'Invalid or expired token: ' . $e->getMessage()
                ], 401);
            }

            // Extract user ID from payload (sub claim preferred, fallback to user_id)
            $userId = $payload['sub'] ?? $payload['user_id'] ?? null;
            if (!$userId) {
                return response()->json([
                    'error' => 'VALIDATION_ERROR',
                    'message' => 'Token payload missing user identifier (sub or user_id)'
                ], 401);
            }

            // Set requester_user_id as request attribute
            $request->attributes->set('requester_user_id', $userId);
        }
        // If no Authorization header, continue without setting requester_user_id
        // (Route handlers can check for personal scope and require token)

        return $next($request);
    }

    /**
     * Verify JWT token using HS256 algorithm.
     *
     * @param string $token JWT token
     * @param string $secret JWT secret
     * @return array Decoded payload
     * @throws \Exception If token is invalid or expired
     */
    private function verifyJWT(string $token, string $secret): array
    {
        // Split token into parts (header.payload.signature)
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            throw new \Exception('Invalid token format');
        }

        // Decode payload (base64url decode)
        $payloadB64 = $parts[1];
        $payloadB64Padded = str_pad(strtr($payloadB64, '-_', '+/'), strlen($payloadB64) % 4, '=', STR_PAD_RIGHT);
        $payloadJson = base64_decode($payloadB64Padded, true);
        if (!$payloadJson) {
            throw new \Exception('Invalid payload encoding');
        }

        $payload = json_decode($payloadJson, true);
        if (!$payload || !is_array($payload)) {
            throw new \Exception('Invalid payload structure');
        }

        // Verify expiration
        if (isset($payload['exp']) && $payload['exp'] < time()) {
            throw new \Exception('Token expired');
        }

        // Verify signature (HMAC-SHA256)
        $headerB64 = $parts[0];
        $signatureB64 = $parts[2];
        $data = $headerB64 . '.' . $payloadB64;
        $expectedSignature = hash_hmac('sha256', $data, $secret, true);
        // Base64url encode signature (no padding)
        $expectedSignatureB64 = strtr(rtrim(base64_encode($expectedSignature), '='), '+/', '-_');

        if (!hash_equals($expectedSignatureB64, $signatureB64)) {
            throw new \Exception('Invalid signature');
        }

        return $payload;
    }
}

