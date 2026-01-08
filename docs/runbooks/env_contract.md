# Environment & Secrets Contract Runbook

## Overview

Environment & Secrets Contract Pack v1 ensures that required environment variables are set and production guardrails are enforced.

## Required Environment Variables

### Always Required

- **APP_ENV**: Application environment (`local`, `dev`, `production`, `prod`)
- **APP_KEY**: Laravel application key (must be set, no weak values)
- **DB_HOST**: Database host
- **DB_DATABASE**: Database name
- **DB_USERNAME**: Database username
- **DB_PASSWORD**: Database password (must not be weak/default)

### Production-Only Requirements

When `APP_ENV=production` or `APP_ENV=prod`:

- **CORS_ALLOWED_ORIGINS**: Comma-separated list of allowed origins (must NOT contain `*`)
- **SESSION_SECURE_COOKIE**: Must be `true` (HTTPS-only cookies)
- **SESSION_SAME_SITE**: Must be `lax` or `strict` (WARN if missing, FAIL if `none` without `SESSION_SECURE_COOKIE=true`)

### Optional (OIDC/JWT)

If OIDC is enabled (`HOS_OIDC_ISSUER` is set):

- **HOS_OIDC_ISSUER**: OIDC issuer URL
- **HOS_OIDC_CLIENT_ID**: OIDC client ID (optional, defaults to `pazar-client`)
- **HOS_OIDC_API_KEY**: OIDC API key (optional, but must not be weak if set)

## Running Locally

### Basic Usage

```powershell
.\ops\env_contract.ps1
```

### Setting Environment Variables

```powershell
# Local development
$env:APP_ENV = "local"
$env:APP_KEY = "base64:your-key-here"
$env:DB_HOST = "localhost"
$env:DB_DATABASE = "pazar"
$env:DB_USERNAME = "pazar"
$env:DB_PASSWORD = "your-password"

# Production
$env:APP_ENV = "production"
$env:CORS_ALLOWED_ORIGINS = "https://example.com,https://app.example.com"
$env:SESSION_SECURE_COOKIE = "true"
$env:SESSION_SAME_SITE = "strict"
```

### Expected Output

```
=== ENVIRONMENT & SECRETS CONTRACT CHECK ===
Timestamp: 2026-01-08 12:00:00

APP_ENV: local

=== Checking Required Environment Variables ===

=== Checking Production Guardrails ===

=== Checking Optional Secrets (OIDC/JWT) ===

=== ENVIRONMENT CONTRACT CHECK RESULTS ===

Check                      Status Notes
-----                      ------ -----
APP_ENV                    PASS   Set (value hidden for security)
APP_KEY                    PASS   Set (value hidden for security)
DB_HOST                    PASS   Set (value hidden for security)
DB_DATABASE                PASS   Set (value hidden for security)
DB_USERNAME                PASS   Set (value hidden for security)
DB_PASSWORD                PASS   Set (value hidden for security)
CORS_ALLOWED_ORIGINS (PROD) PASS   Set with strict allowlist (no wildcard)
SESSION_SECURE_COOKIE (PROD) PASS  Set to 'true' (HTTPS-only cookies)
SESSION_SAME_SITE (PROD)    PASS   Set to 'strict' (CSRF protection)

OVERALL STATUS: PASS (All checks passed)
```

## Production Guardrails

### CORS Policy

**Requirement**: `CORS_ALLOWED_ORIGINS` must NOT contain `*` in production

**Example (CORRECT)**:
```env
CORS_ALLOWED_ORIGINS=https://example.com,https://app.example.com
```

**Example (INCORRECT)**:
```env
CORS_ALLOWED_ORIGINS=*
```

### Session Cookie Security

**Requirement**: `SESSION_SECURE_COOKIE=true` in production

**Example (CORRECT)**:
```env
SESSION_SECURE_COOKIE=true
```

**Example (INCORRECT)**:
```env
SESSION_SECURE_COOKIE=false
# or missing
```

### Same-Site Cookie Policy

**Requirement**: `SESSION_SAME_SITE` must be `lax` or `strict` in production

**Example (CORRECT)**:
```env
SESSION_SAME_SITE=strict
# or
SESSION_SAME_SITE=lax
```

**Example (INCORRECT)**:
```env
SESSION_SAME_SITE=none
# (only allowed if SESSION_SECURE_COOKIE=true)
```

## Weak/Default Secrets Detection

The check fails if any of these weak values are detected:

- Empty strings
- `password`
- `secret`
- `changeme`
- `base64:` (for APP_KEY, must be a full base64 key)

### Fixing Weak Secrets

1. **APP_KEY**: Generate new key:
   ```bash
   php artisan key:generate
   ```

2. **DB_PASSWORD**: Use strong password (min 16 chars, mixed case, numbers, symbols)

3. **HOS_OIDC_API_KEY**: Generate secure random string (32+ chars)

## CI Integration

The env contract check runs in CI with GitHub secrets:

- Secrets are automatically passed as environment variables
- Check validates all required vars are set
- Production guardrails are enforced when `APP_ENV=production`

### Setting GitHub Secrets

1. Go to repository Settings → Secrets and variables → Actions
2. Add required secrets:
   - `APP_ENV`
   - `APP_KEY`
   - `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
   - `CORS_ALLOWED_ORIGINS` (production)
   - `SESSION_SECURE_COOKIE`, `SESSION_SAME_SITE` (production)
   - `HOS_OIDC_*` (if OIDC is enabled)

## Troubleshooting

### Missing Required Variables

**Symptom**: Check fails with "Missing required environment variable"

**Fix**:
1. Set the missing variable in your environment
2. For CI, add it to GitHub secrets
3. For local, set in `.env` file or PowerShell session

### Weak Secrets Detected

**Symptom**: Check fails with "Weak or default value detected"

**Fix**:
1. Replace weak value with strong secret
2. Generate new keys/passwords
3. Update `.env` file or GitHub secrets

### Production Guardrails Not Met

**Symptom**: Check fails in production mode

**Fix**:
1. Set `CORS_ALLOWED_ORIGINS` with strict allowlist (no wildcard)
2. Set `SESSION_SECURE_COOKIE=true`
3. Set `SESSION_SAME_SITE='lax'` or `'strict'`

### CORS Wildcard in Production

**Symptom**: "Contains wildcard '*' (security risk in production)"

**Fix**:
```env
# Remove wildcard, use explicit allowlist
CORS_ALLOWED_ORIGINS=https://example.com,https://app.example.com
```

## Related Documentation

- `docs/RULES.md` - Rule 31: PR merge requires env-contract PASS for production-related changes
- `ops/env_contract.ps1` - Environment contract check script
- `.github/workflows/env-contract.yml` - CI workflow
- `work/pazar/config/session.php` - Session configuration
- `work/pazar/app/Http/Middleware/Cors.php` - CORS middleware

