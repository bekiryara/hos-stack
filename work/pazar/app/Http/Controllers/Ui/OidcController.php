<?php

namespace App\Http\Controllers\Ui;

use App\Http\Controllers\Controller;
use App\Models\User;
use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class OidcController extends Controller
{
    public function redirect(Request $request): RedirectResponse
    {
        // Allow direct /ui/oidc/login usage if issuer is configured, even if feature flag is off.
        // (The /ui/login auto-redirect remains feature-flag controlled.)
        // For browser redirect, use oidc.issuer (localhost:3000) - browser can't resolve hos-api
        // hos.remote.base_url (hos-api:3000) is only for container-internal HTTP calls
        $issuer = rtrim((string) (config('oidc.issuer', '') ?: config('hos.remote.base_url', '')), '/');
        $clientId = (string) config('oidc.client_id', '');
        $redirectUri = (string) config('oidc.redirect_uri', '');
        $world = (string) config('oidc.world', 'commerce');
        $scopes = (string) config('oidc.scopes', 'openid profile email');

        if ($redirectUri === '') {
            // Compute exact callback URL including subdirectory base (e.g. /pazar/index.php).
            $redirectUri = $request->getSchemeAndHttpHost().$request->getBaseUrl().'/ui/oidc/callback';
        }

        abort_if($issuer === '' || $redirectUri === '' || $clientId === '', 500, 'OIDC is not configured.');

        $state = Str::random(32);
        $verifier = $this->pkceVerifier();
        $challenge = $this->pkceChallenge($verifier);

        // Store in session (primary)
        $request->session()->put('oidc.state', $state);
        $request->session()->put('oidc.verifier', $verifier);
        $request->session()->put('oidc.started_at', now()->timestamp);
        
        // Force session save before external redirect (critical for Docker)
        $request->session()->save();
        
        // Also store in cache as fallback for Docker external redirect cookie loss
        // Cache key uses state as lookup key (state is in redirect URL, survives cookie loss)
        Cache::put('oidc.state.'.$state, [
            'state' => $state,
            'verifier' => $verifier,
            'started_at' => now()->timestamp,
        ], now()->addMinutes(5));

        $query = http_build_query([
            'response_type' => 'code',
            'client_id' => $clientId,
            'redirect_uri' => $redirectUri,
            'scope' => $scopes,
            'state' => $state,
            'code_challenge' => $challenge,
            'code_challenge_method' => 'S256',
            'world' => $world,
            // Pre-fill form fields for convenience
            'tenantSlug' => 'demo',
            'email' => 'admin@demo.local',
        ]);

        return redirect()->away($issuer.'/authorize?'.$query);
    }

    public function callback(Request $request): RedirectResponse
    {
        // Prefer hos.remote.base_url for Docker network compatibility (hos-api:3000)
        // Fallback to oidc.issuer if remote.base_url is not set
        $issuer = rtrim((string) (config('hos.remote.base_url', '') ?: config('oidc.issuer', '')), '/');
        $clientId = (string) config('oidc.client_id', '');
        $redirectUri = (string) config('oidc.redirect_uri', '');

        if ($redirectUri === '') {
            // Compute exact callback URL including subdirectory base (e.g. /pazar/index.php).
            // MUST match the redirectUri used in redirect() method.
            $redirectUri = $request->getSchemeAndHttpHost().$request->getBaseUrl().'/ui/oidc/callback';
        }

        abort_if($issuer === '' || $redirectUri === '' || $clientId === '', 500, 'OIDC is not configured.');

        $code = (string) $request->query('code', '');
        $state = (string) $request->query('state', '');
        
        // Try session first (normal flow)
        $expectedState = (string) $request->session()->pull('oidc.state', '');
        $verifier = (string) $request->session()->pull('oidc.verifier', '');
        
        // Fallback to cache if session lost (Docker external redirect cookie issue)
        // Use received state to lookup cache (state is in URL, so we can find it)
        if (($expectedState === '' || $verifier === '') && $state !== '') {
            $cached = Cache::pull('oidc.state.'.$state);
            if (is_array($cached) && isset($cached['state'], $cached['verifier'])) {
                $expectedState = (string) $cached['state'];
                $verifier = (string) $cached['verifier'];
            }
        }

        if ($code === '' || $state === '' || $expectedState === '' || ! hash_equals($expectedState, $state)) {
            throw new HttpException(400, 'Invalid OIDC state.');
        }
        if ($verifier === '') {
            throw new HttpException(400, 'Missing OIDC verifier.');
        }

        $token = $this->exchangeCode($issuer, $clientId, $redirectUri, $code, $verifier);
        $idToken = (string) ($token['id_token'] ?? '');
        $accessToken = (string) ($token['access_token'] ?? '');
        if ($idToken === '') {
            throw new HttpException(502, 'Missing id_token from OIDC token endpoint.');
        }

        $claims = $this->verifyIdToken($issuer, $clientId, $idToken);

        // Prefer userinfo for profile/email if available.
        $profile = $claims;
        if ($accessToken !== '') {
            try {
                $profile = array_merge($profile, $this->userinfo($issuer, $accessToken));
            } catch (\Throwable $e) {
                // best-effort; keep claims only
            }
        }

        $hosUserId = (string) ($profile['hos_user_id'] ?? $profile['sub'] ?? '');
        if ($hosUserId === '') {
            throw new HttpException(502, 'Missing hos_user_id/sub in OIDC claims.');
        }

        $email = (string) ($profile['email'] ?? '');
        $name = (string) ($profile['name'] ?? ($email !== '' ? $email : 'user'));

        $user = $this->findOrCreateUser($hosUserId, $email, $name);

        Auth::login($user, true);
        $request->session()->regenerate();

        return redirect()->route('ui.dashboard');
    }

    /**
     * @return array<string,mixed>
     */
    protected function exchangeCode(string $issuer, string $clientId, string $redirectUri, string $code, string $verifier): array
    {
        $apiKey = (string) config('oidc.api_key', '');
        $headers = $apiKey !== '' ? ['X-HOS-API-KEY' => $apiKey] : [];
        
        // Propagate request ID to H-OS
        $request = request();
        if ($request->hasHeader('X-Request-Id')) {
            $headers['X-Request-Id'] = $request->header('X-Request-Id');
        } elseif ($request->attributes->has('request_id')) {
            $headers['X-Request-Id'] = $request->attributes->get('request_id');
        }

        $resp = Http::baseUrl($issuer)
            ->acceptJson()
            ->asJson()
            ->withHeaders($headers)
            ->post('/token', [
                'grant_type' => 'authorization_code',
                'client_id' => $clientId,
                'redirect_uri' => $redirectUri,
                'code' => $code,
                'code_verifier' => $verifier,
            ]);

        if (! $resp->successful()) {
            throw new HttpException(502, 'OIDC token endpoint failed: '.$resp->status().' '.$resp->reason());
        }

        $json = $resp->json();
        if (! is_array($json)) {
            throw new HttpException(502, 'OIDC token endpoint returned non-JSON.');
        }

        return $json;
    }

    /**
     * @return array<string,mixed>
     */
    protected function userinfo(string $issuer, string $accessToken): array
    {
        $apiKey = (string) config('oidc.api_key', '');
        $request = request();

        $headers = [
            'Authorization' => 'Bearer '.$accessToken,
        ];
        if ($apiKey !== '') {
            $headers['X-HOS-API-KEY'] = $apiKey;
        }
        
        // Propagate request ID to H-OS
        if ($request->hasHeader('X-Request-Id')) {
            $headers['X-Request-Id'] = $request->header('X-Request-Id');
        } elseif ($request->attributes->has('request_id')) {
            $headers['X-Request-Id'] = $request->attributes->get('request_id');
        }

        $resp = Http::baseUrl($issuer)
            ->acceptJson()
            ->withHeaders($headers)
            ->get('/userinfo');

        if (! $resp->successful()) {
            throw new HttpException(502, 'OIDC userinfo failed: '.$resp->status().' '.$resp->reason());
        }

        $json = $resp->json();
        if (! is_array($json)) {
            throw new HttpException(502, 'OIDC userinfo returned non-JSON.');
        }

        return $json;
    }

    /**
     * @return array<string,mixed>
     */
    protected function verifyIdToken(string $issuer, string $clientId, string $jwt): array
    {
        $jwks = $this->jwks($issuer);

        $keySet = JWK::parseKeySet($jwks);
        $decoded = (array) JWT::decode($jwt, $keySet);

        $iss = (string) ($decoded['iss'] ?? '');
        if ($iss !== $issuer) {
            throw new HttpException(401, 'Invalid token issuer.');
        }

        // aud can be string or array
        $aud = $decoded['aud'] ?? null;
        $audOk = false;
        if (is_string($aud)) {
            $audOk = ($aud === $clientId);
        } elseif (is_array($aud)) {
            $audOk = in_array($clientId, $aud, true);
        }

        if (! $audOk) {
            throw new HttpException(401, 'Invalid token audience.');
        }

        /** @var array<string,mixed> $decoded */
        return $decoded;
    }

    /**
     * @return array<string,mixed>
     */
    protected function jwks(string $issuer): array
    {
        $ttl = (int) config('oidc.jwks_cache_ttl_seconds', 300);
        $cacheKey = 'oidc.jwks.'.sha1($issuer);

        return Cache::remember($cacheKey, $ttl, function () use ($issuer): array {
            // Propagate request ID to H-OS
            $request = request();
            $headers = [];
            if ($request->hasHeader('X-Request-Id')) {
                $headers['X-Request-Id'] = $request->header('X-Request-Id');
            } elseif ($request->attributes->has('request_id')) {
                $headers['X-Request-Id'] = $request->attributes->get('request_id');
            }
            
            $resp = Http::baseUrl($issuer)->acceptJson()->withHeaders($headers)->get('/jwks.json');
            if (! $resp->successful()) {
                throw new HttpException(502, 'OIDC JWKS fetch failed: '.$resp->status().' '.$resp->reason());
            }
            $json = $resp->json();
            if (! is_array($json)) {
                throw new HttpException(502, 'OIDC JWKS returned non-JSON.');
            }
            return $json;
        });
    }

    protected function pkceVerifier(): string
    {
        // 43..128 chars. Use URL-safe base64 without padding.
        $raw = random_bytes(32);
        return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
    }

    protected function pkceChallenge(string $verifier): string
    {
        $hash = hash('sha256', $verifier, true);
        return rtrim(strtr(base64_encode($hash), '+/', '-_'), '=');
    }

    protected function findOrCreateUser(string $hosUserId, string $email, string $name): User
    {
        $u = User::query()->where('hos_user_id', $hosUserId)->first();
        if ($u) {
            return $u;
        }

        if ($email !== '') {
            $existingByEmail = User::query()->where('email', $email)->first();
            if ($existingByEmail) {
                $currentHos = (string) ($existingByEmail->hos_user_id ?? '');
                if ($currentHos !== '' && $currentHos !== $hosUserId) {
                    // Fail-fast: do NOT silently create a duplicate Pazar user for the same email.
                    // This indicates identity drift (same email maps to different hos_user_id).
                    throw new HttpException(409, 'Identity drift: this email is already linked to a different hos_user_id.');
                }
                $existingByEmail->forceFill([
                    'hos_user_id' => $hosUserId,
                ])->save();
                return $existingByEmail;
            }
        }

        // Email is required by schema (unique). If userinfo didn't provide it, create a deterministic placeholder.
        $finalEmail = $email !== '' ? $email : ('hos_'.$hosUserId.'@example.local');

        return User::query()->create([
            'name' => $name !== '' ? $name : $finalEmail,
            'email' => $finalEmail,
            'password' => null,
            'hos_user_id' => $hosUserId,
        ]);
    }
}


