<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Auth Any Middleware
 * 
 * Allows request if user is authenticated via any method (session or bearer token).
 * For bearer token: checks if token matches HOS_OIDC_API_KEY env var (if set).
 */
final class AuthAny
{
    /**
     * Handle an incoming request
     * 
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Check if user is authenticated via session
        if (Auth::check()) {
            return $next($request);
        }

        // Check bearer token against HOS_OIDC_API_KEY (if set) OR validate as JWT
        $bearerToken = $request->bearerToken();
        if ($bearerToken !== null) {
            $apiKey = env('HOS_OIDC_API_KEY');
            if ($apiKey !== null && $apiKey !== '' && $bearerToken === $apiKey) {
                return $next($request);
            }
            
            // WP-50: Also validate as JWT token (allows user-like auth flow)
            $jwtSecret = env('HOS_JWT_SECRET') ?: env('JWT_SECRET');
            if ($jwtSecret && strlen($jwtSecret) >= 32) {
                try {
                    // Use same JWT verification logic as AuthContext
                    $payload = $this->verifyJWT($bearerToken, $jwtSecret);
                    // If JWT is valid, allow request
                    return $next($request);
                } catch (\Exception $e) {
                    // JWT validation failed, continue to 401
                }
            }
        }

        // Not authenticated: return 401
        $requestId = $request->attributes->get('request_id', '');
        if (empty($requestId)) {
            $requestId = (string) \Illuminate\Support\Str::uuid();
        }

        $response = response()->json([
            'ok' => false,
            'error_code' => 'UNAUTHORIZED',
            'message' => 'Unauthenticated.',
            'request_id' => $requestId,
        ], 401);

        return $response->header('X-Request-Id', $requestId);
    }
    
    /**
     * Verify JWT token using HS256 algorithm (WP-50: same logic as AuthContext).
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






