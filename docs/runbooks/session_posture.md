# Session Posture Runbook

## Overview

Identity & Session Posture Pack v1 ensures proper session security configuration and auth endpoint security posture for production environments.

## Session Cookie Posture

### Required Cookie Flags (Production)

In production (`APP_ENV=production`), session cookies must have:

- **Secure**: `SESSION_SECURE_COOKIE=true` - Cookies only sent over HTTPS
- **HttpOnly**: `SESSION_HTTP_ONLY=true` - Cookies not accessible via JavaScript
- **SameSite**: `SESSION_SAME_SITE='lax'` or `'strict'` - CSRF protection

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

### SameSite Policy

- **`lax`**: Allows cookies in top-level navigations (recommended for most cases)
- **`strict`**: Most restrictive, blocks all cross-site requests (maximum security)
- **`none`**: Only allowed if `SESSION_SECURE_COOKIE=true` (not recommended)

### Local/Dev Mode

In local/dev mode, these checks are recommendations only (WARN, not FAIL).

## Auth Endpoint Security

### Required Response Format

Auth endpoints (e.g., `/auth/login`) must return:

1. **JSON Envelope**: Standard error envelope format
   ```json
   {
     "ok": false,
     "error_code": "VALIDATION_ERROR",
     "message": "...",
     "request_id": "<uuid>"
   }
   ```

2. **Security Headers** (from EDGE SECURITY PACK):
   - `X-Content-Type-Options: nosniff`
   - `X-Frame-Options: DENY`
   - `Referrer-Policy: no-referrer`

3. **Rate Limit Headers** (on throttled requests):
   - `X-RateLimit-Limit`: Maximum requests allowed
   - `X-RateLimit-Remaining`: Remaining requests
   - `Retry-After`: Seconds to wait (on 429)

## Running Locally

### Basic Usage

```powershell
.\ops\session_posture_check.ps1
```

### Setting Environment Variables

```powershell
# Production mode
$env:APP_ENV = "production"
$env:SESSION_SECURE_COOKIE = "true"
$env:SESSION_HTTP_ONLY = "true"
$env:SESSION_SAME_SITE = "strict"
$env:CORS_ALLOWED_ORIGINS = "https://example.com,https://app.example.com"

# Local mode (recommendations only)
$env:APP_ENV = "local"
```

### Expected Output

```
=== IDENTITY & SESSION POSTURE CHECK ===
Timestamp: 2026-01-08 12:00:00

APP_ENV: production

=== Checking Session Cookie Configuration ===

=== Checking Auth Endpoint Response ===

=== SESSION POSTURE CHECK RESULTS ===

Check                          Status Notes
-----                          ------ -----
Session Cookie Configuration   PASS   All session cookie flags correct (Secure, HttpOnly, SameSite)
Auth Endpoint Response         PASS   JSON envelope, security headers, and rate limit headers present

OVERALL STATUS: PASS (All checks passed)
```

## Fixing Failures

### Session Cookie Flags Missing

**Symptom**: "SESSION_SECURE_COOKIE must be 'true' in production"

**Fix**:
1. Set `SESSION_SECURE_COOKIE=true` in `.env` or environment
2. Clear config cache: `php artisan config:clear`
3. Restart application

### SameSite Policy Issue

**Symptom**: "SESSION_SAME_SITE='none' requires SESSION_SECURE_COOKIE=true"

**Fix**:
1. Set `SESSION_SAME_SITE='lax'` or `'strict'` (recommended)
2. OR set `SESSION_SECURE_COOKIE=true` if `SESSION_SAME_SITE='none'` is required

### Security Headers Missing

**Symptom**: "Missing security header: X-Content-Type-Options"

**Fix**:
1. Verify `SecurityHeaders` middleware is registered in `bootstrap/app.php`
2. Check middleware order (SecurityHeaders should be early in the stack)
3. Verify route path matches `/api/*` or `/auth/*` pattern

### Rate Limit Headers Missing

**Symptom**: "Rate limit headers not present"

**Fix**:
1. Verify throttle middleware is applied to route
2. Check rate limiter configuration in `AppServiceProvider`
3. Ensure Laravel's throttle middleware is working correctly

## Relationship to Other Runbooks

- **`docs/runbooks/env_contract.md`**: Environment variable validation (CORS, session config)
- **`docs/runbooks/security_auth.md`**: Auth security hardening (cookie flags, CSRF, rate limiting)
- **`docs/runbooks/tenant_boundary.md`**: Tenant isolation and boundary checks
- **`docs/runbooks/security_edge.md`**: Edge security (CORS, security headers)

## Troubleshooting

### Docker Services Not Running

**Symptom**: "Docker services not running, endpoint checks skipped"

**Fix**:
1. Start docker compose: `docker compose up -d`
2. Wait for services to be ready
3. Re-run the check

### Config Cache Issues

**Symptom**: Changes to `.env` not reflected

**Fix**:
1. Clear config cache: `php artisan config:clear`
2. Restart application
3. Verify environment variables are loaded

### False Positives

**Symptom**: Check fails but configuration looks correct

**Fix**:
1. Verify environment variables are actually set (not just in `.env`)
2. Check config cache is cleared
3. Verify middleware registration order

## Related Documentation

- `docs/RULES.md` - Rule 32: Session-posture gate PASS required for auth-related PRs
- `ops/session_posture_check.ps1` - Session posture check script
- `.github/workflows/session-posture.yml` - CI workflow
- `work/pazar/config/session.php` - Session configuration
- `work/pazar/app/Http/Middleware/SecurityHeaders.php` - Security headers middleware

