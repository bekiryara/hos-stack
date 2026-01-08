# Auth Security Runbook

## Overview

Auth Security Hardening Pack v1 ensures proper authentication and authorization protection, rate limiting, and session security.

## Cookie/Session Hardening Checklist

### Required Cookie Flags (PROD)

In production, session cookies must have the following flags:

- **Secure**: `SESSION_SECURE_COOKIE=true` - Cookies only sent over HTTPS
- **HttpOnly**: `SESSION_HTTP_ONLY=true` - Cookies not accessible via JavaScript
- **SameSite**: `SESSION_SAME_SITE=strict` - CSRF protection (strict mode)

### Configuration

Set in `.env` (production):

```env
SESSION_SECURE_COOKIE=true
SESSION_HTTP_ONLY=true
SESSION_SAME_SITE=strict
```

Or in `config/session.php`:

```php
'secure' => env('SESSION_SECURE_COOKIE', true),
'http_only' => env('SESSION_HTTP_ONLY', true),
'same_site' => env('SESSION_SAME_SITE', 'strict'),
```

### Session Rotation

- **Lifetime**: Default 120 minutes (configurable via `SESSION_LIFETIME`)
- **Rotation**: Laravel automatically rotates session ID on login
- **Expiration**: Sessions expire on browser close if `SESSION_EXPIRE_ON_CLOSE=true`

## CSRF Posture

### API/Auth Routes

- **CSRF Exempt**: `/auth/*`, `/admin/*`, `/panel/*` routes are exempt from CSRF protection
- **Reason**: Token-authenticated requests and webhooks work in real HTTP clients
- **Protection**: Authentication middleware (`auth.any`, `super.admin`, `tenant.user`) provides authorization protection

### Panel Routes

- **CSRF Protected**: UI panel routes (session-based) use Laravel's CSRF protection
- **Token**: CSRF token included in forms and validated on POST requests
- **Exception**: API endpoints exempt for token authentication

### Configuration

CSRF exemptions in `bootstrap/app.php`:

```php
$middleware->validateCsrfTokens(except: [
    'auth/*',
    'admin/*',
    'panel/*',
    'products',
    'orders*',
    'reservations*',
    'payments*',
]);
```

## Rate Limit Policy

### Auth Endpoints

- **Endpoint**: `POST /auth/login`
- **Limit**: 30 requests per minute per IP (or per authenticated user)
- **Burst**: Small burst allowed (throttle middleware handles this)
- **Response**: 429 Too Many Requests when limit exceeded

### Rate Limiter Configuration

Defined in `app/Providers/AppServiceProvider.php`:

```php
RateLimiter::for('public-write', function (Request $request) {
    $key = ($request->user()?->id ?? $request->ip()).'|tenant:'.($request->tenant?->id ?? 'none');
    return Limit::perMinute(30)->by($key);
});
```

### Rate Limit Headers

When rate limit is enforced, response includes:

- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Remaining requests in current window
- `Retry-After`: Seconds to wait before retrying (on 429)

### Other Endpoints

- **Panel write endpoints**: 60 requests per minute (`throttle:panel-write`)
- **Webhook endpoints**: 120 requests per minute (`throttle:webhook`)

## Troubleshooting

### Unauthorized Access Returns 200

**Symptom**: GET `/admin/*` or `/panel/*` without auth returns 200 OK

**Cause**: Missing or incorrect middleware configuration

**Fix**:
1. Verify route middleware in `routes/admin.php` and `routes/panel.php`
2. Ensure `auth.any` middleware is applied
3. Check middleware registration in `bootstrap/app.php`

### Rate Limiting Not Working

**Symptom**: Rate limit not enforced after 30 requests

**Cause**: Throttle middleware not applied or cache issue

**Fix**:
1. Verify `throttle:public-write` middleware on route
2. Clear cache: `php artisan cache:clear`
3. Check rate limiter configuration in `AppServiceProvider`

### Session Cookie Not Secure

**Symptom**: Cookies sent over HTTP in production

**Cause**: `SESSION_SECURE_COOKIE` not set to `true`

**Fix**:
1. Set `SESSION_SECURE_COOKIE=true` in `.env`
2. Clear config cache: `php artisan config:clear`
3. Restart application

### CSRF Token Mismatch

**Symptom**: 419 error on POST requests to panel routes

**Cause**: CSRF token missing or expired

**Fix**:
1. Ensure CSRF token included in form: `@csrf`
2. Check session configuration
3. Verify `SESSION_DRIVER` is set correctly

## Related Documentation

- `docs/RULES.md` - Rule 28: Auth surface must have auth-security gate PASS for merge
- `ops/auth_security_check.ps1` - Auth security check script
- `.github/workflows/auth-security.yml` - CI workflow
- `work/pazar/config/session.php` - Session configuration
- `work/pazar/app/Providers/AppServiceProvider.php` - Rate limiter configuration

