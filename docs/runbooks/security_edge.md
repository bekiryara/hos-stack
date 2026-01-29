# Security Edge Runbook

## Overview

Security Edge Pack v1 provides CORS policy, security headers, and rate limiting for API/auth endpoints.

## CORS Policy

### Configuration

CORS is environment-based:
- **DEV/LOCAL**: Allows all origins or localhost allowlist (localhost, 127.0.0.1, ::1)
- **PROD**: Strict allowlist from `CORS_ALLOWED_ORIGINS` environment variable (comma-separated)

### Setting CORS_ALLOWED_ORIGINS

In production, set `CORS_ALLOWED_ORIGINS` in `.env`:

```env
CORS_ALLOWED_ORIGINS=https://example.com,https://app.example.com
```

### CORS Headers

- `Access-Control-Allow-Origin`: Set based on origin (if allowed)
- `Access-Control-Allow-Credentials`: `false` (no credentials needed)
- `Access-Control-Allow-Methods`: `GET,POST,PUT,PATCH,DELETE,OPTIONS`
- `Access-Control-Allow-Headers`: `Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept, X-Active-Tenant-Id, Idempotency-Key`
- `Access-Control-Max-Age`: `86400` (24 hours)

### Testing CORS

Test preflight request:
```bash
curl.exe -i -X OPTIONS http://localhost:8080/api/non-existent-endpoint \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: GET"
```

Expected headers:
- `Access-Control-Allow-Origin: http://localhost:5173` (if allowed)
- `Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS`
- `Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-Id, X-Requested-With, Accept, X-Active-Tenant-Id, Idempotency-Key`

## Security Headers

Security headers are applied to `/api/*` and `/auth/*` routes:

- **X-Content-Type-Options**: `nosniff` - Prevents MIME type sniffing
- **X-Frame-Options**: `DENY` - Prevents clickjacking attacks
- **Referrer-Policy**: `no-referrer` - Prevents referrer information leakage
- **Permissions-Policy**: `geolocation=(), microphone=(), camera=()` - Disables sensitive permissions
- **Content-Security-Policy**: `default-src 'none'; frame-ancestors 'none'; base-uri 'none'` - Minimal CSP (prevents framing and base URI manipulation)

### Testing Security Headers

Test API endpoint:
```bash
curl.exe -i http://localhost:8080/api/non-existent-endpoint
```

Expected headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: no-referrer`
- `Permissions-Policy: geolocation=(), microphone=(), camera=()`
- `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'; base-uri 'none'`

## Rate Limiting

### Auth Endpoints

`/auth/login` is rate-limited to **30 requests per minute per IP** (or per authenticated user).

Rate limiter configuration:
- **Name**: `public-write`
- **Limit**: 30 requests per minute
- **Key**: User ID (if authenticated) or IP address

### Other Endpoints

- **Panel write endpoints**: 60 requests per minute (throttle:panel-write)
- **Webhook endpoints**: 120 requests per minute (throttle:webhook)

### Testing Rate Limiting

Test auth endpoint:
```bash
# First request (should succeed)
curl.exe -i -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d "{}"

# After 30 requests in 1 minute, should return 429 Too Many Requests
```

### Rate Limit Response

When rate limit is exceeded, Laravel returns:
- **Status**: `429 Too Many Requests`
- **Headers**: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After`
- **Body**: Standard error envelope with `error_code: RATE_LIMIT_EXCEEDED`

## Troubleshooting

### CORS Issues

1. **Preflight fails**: Check `CORS_ALLOWED_ORIGINS` in production
2. **Origin not allowed**: Verify origin matches allowlist exactly (including protocol and port)
3. **Credentials issue**: Ensure `Access-Control-Allow-Credentials` is `false` (no credentials needed)

### Security Headers Not Present

1. **Check route path**: Security headers only apply to `/api/*` and `/auth/*`
2. **Check middleware order**: SecurityHeaders middleware must be registered before response is sent
3. **Check nginx**: Nginx may override headers; ensure middleware runs before nginx adds headers

### Rate Limiting Issues

1. **Too strict**: Adjust rate limiter in `AppServiceProvider::boot()` (RateLimiter::for('public-write'))
2. **Not working**: Verify throttle middleware is applied to routes
3. **Cache issue**: Clear cache: `php artisan cache:clear`

## Related Documentation

- `docs/RULES.md` - Rule 26: PROD must not use wildcard CORS
- `work/pazar/app/Http/Middleware/Cors.php` - CORS middleware implementation
- `work/pazar/app/Http/Middleware/SecurityHeaders.php` - Security headers middleware implementation
- `work/pazar/app/Providers/AppServiceProvider.php` - Rate limiter configuration

