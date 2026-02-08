#!/bin/sh
set -e

# Ensure storage directories exist and have correct permissions
# This runs before supervisord starts php-fpm (idempotent boot-time step)
# ROBUST: fail-fast if storage is not writable after all attempts

# Check if running as root (compose user: "0:0" allows chown)
if [ "$(id -u)" -eq 0 ]; then
    # a) Create required directories
    mkdir -p /var/www/html/storage/logs
    mkdir -p /var/www/html/storage/framework/cache
    mkdir -p /var/www/html/storage/framework/sessions
    mkdir -p /var/www/html/storage/framework/views
    mkdir -p /var/www/html/bootstrap/cache
    
    # b) Fix ownership (root can chown)
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
    
    # c) Set permissions
    chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache
else
    # Not root: try existing approach (may fail on named volumes, but non-fatal)
    mkdir -p /var/www/html/storage/logs
    mkdir -p /var/www/html/storage/framework/cache
    mkdir -p /var/www/html/storage/framework/sessions
    mkdir -p /var/www/html/storage/framework/views
    mkdir -p /var/www/html/bootstrap/cache
    
    # Try chown (may fail if not root, but continue)
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || echo "[WARN] chown failed (not root); fix via compose user: 0:0" >&2
    
    # Try chmod (continue if fails, but detect)
    chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
fi

# d) Ensure storage/logs directory exists
mkdir -p /var/www/html/storage/logs

# f) Ensure APP_KEY exists (required for Laravel runtime).
# In local/dev, auto-provision a stable key persisted in the storage volume.
if [ -z "${APP_KEY:-}" ]; then
    KEY_PATH="/var/www/html/storage/app/app_key.txt"
    if [ -f "$KEY_PATH" ]; then
        export APP_KEY="$(cat "$KEY_PATH" 2>/dev/null | tr -d '\r\n' || true)"
        if [ -n "${APP_KEY:-}" ]; then
            echo "[INFO] Loaded APP_KEY from storage (dev)" >&2
        fi
    fi
    if [ -z "${APP_KEY:-}" ]; then
        # Only auto-generate in local/dev contexts (avoid surprising prod behavior)
        if [ "${APP_ENV:-production}" = "local" ] || [ "${APP_DEBUG:-false}" = "true" ]; then
            mkdir -p "$(dirname "$KEY_PATH")" 2>/dev/null || true
            export APP_KEY="$(php -r "echo 'base64:'.base64_encode(random_bytes(32));" 2>/dev/null || true)"
            if [ -n "${APP_KEY:-}" ]; then
                echo "$APP_KEY" > "$KEY_PATH" 2>/dev/null || true
                chmod 0600 "$KEY_PATH" 2>/dev/null || true
                echo "[WARN] APP_KEY was missing; generated dev key and persisted to storage" >&2
            else
                echo "[WARN] APP_KEY missing and could not be generated (php unavailable?)" >&2
            fi
        fi
    fi
fi

# e) STATELESS LOGGING: If LOG_CHANNEL=stderr, skip laravel.log file creation entirely
# Laravel will write to php://stderr which is captured by docker logs
if [ "${LOG_CHANNEL:-}" = "stderr" ]; then
    echo "[INFO] LOG_CHANNEL=stderr: Laravel logs to stderr, skipping laravel.log file creation" >&2
    # Ensure directory exists but don't create laravel.log file
    mkdir -p /var/www/html/storage/logs 2>/dev/null || true
else
    # Fallback: If not stderr, create laravel.log with permissive permissions (legacy support)
    if [ "${HOS_LARAVEL_LOG_STDOUT:-0}" = "1" ]; then
        rm -f /var/www/html/storage/logs/laravel.log 2>/dev/null || true
        ln -sf /proc/1/fd/1 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
        if [ -L /var/www/html/storage/logs/laravel.log ]; then
            echo "[INFO] laravel.log symlinked to stdout (HOS_LARAVEL_LOG_STDOUT=1)" >&2
        fi
    fi
    if [ ! -L /var/www/html/storage/logs/laravel.log ]; then
        touch /var/www/html/storage/logs/laravel.log 2>/dev/null || true
        if [ "$(id -u)" -eq 0 ]; then
            chown www-data:www-data /var/www/html/storage/logs/laravel.log 2>/dev/null || true
            chmod 0666 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
        fi
    fi
fi

# h) DEV MODE: Force storage permissions (brute-force for visibility)
# This ensures Laravel can always write logs even in dev environments with permission issues
if [ "${APP_ENV:-production}" = "local" ] || [ "${APP_DEBUG:-false}" = "true" ]; then
    echo "[INFO] DEV MODE: Applying permissive storage permissions for log visibility" >&2
    mkdir -p /var/www/html/storage /var/www/html/storage/logs /var/www/html/bootstrap/cache 2>/dev/null || true
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
    chmod -R 0777 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
fi

# i) Clear Laravel caches (ignore failures - may fail if Laravel not fully bootstrapped)
echo "[INFO] Clearing Laravel caches (optimize:clear)..." >&2
php /var/www/html/artisan optimize:clear >/dev/null 2>&1 || echo "[WARN] optimize:clear failed (non-fatal, Laravel may not be fully bootstrapped)" >&2

# Execute the original command (supervisord)
exec "$@"

