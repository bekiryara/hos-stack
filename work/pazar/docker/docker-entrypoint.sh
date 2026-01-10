#!/bin/sh
set -e

# Ensure storage directories exist and have correct permissions
# This runs before supervisord starts php-fpm (idempotent boot-time step)
# ROBUST: fail-fast if storage is not writable after all attempts

# a) Create required directories
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/bootstrap/cache

# b) Try chown (continue if fails, but detect)
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# c) Try chmod (continue if fails, but detect)
chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# d) Writability probe: try touch laravel.log
if ! touch /var/www/html/storage/logs/laravel.log 2>/dev/null; then
    # Fallback: try 0777 permissions as last resort
    chmod -R 0777 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
    # Try touch again
    if ! touch /var/www/html/storage/logs/laravel.log 2>/dev/null; then
        echo "[FAIL] storage not writable: /var/www/html/storage/logs/laravel.log" >&2
        exit 1
    fi
fi

# Execute the original command (supervisord)
exec "$@"

