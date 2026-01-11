#!/bin/sh
set -e

# Storage Self-Heal Script
# Ensures storage/logs and bootstrap/cache are writable by php-fpm user (www-data)
# Runs on every container start (idempotent)
# Prevents Monolog "Permission denied" errors

# Check if running as root (compose user: "0:0" allows chown)
if [ "$(id -u)" -eq 0 ]; then
    # a) Create required directories
    mkdir -p /var/www/html/storage/logs
    mkdir -p /var/www/html/bootstrap/cache
    
    # b) Fix ownership (root can chown)
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
    
    # c) Set permissions
    chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
    
    # d) Ensure laravel.log exists and is writable
    touch /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    chown www-data:www-data /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    # CRITICAL: chmod 0666 for bulletproof append (worker can write even if ownership gets weird)
    chmod 0666 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
else
    # Not root: try existing approach (may fail on named volumes, but non-fatal)
    mkdir -p /var/www/html/storage/logs
    mkdir -p /var/www/html/bootstrap/cache
    
    # Try chown (may fail if not root, but continue)
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || echo "[WARN] chown failed (not root); fix via compose user: 0:0" >&2
    
    # Try chmod (continue if fails, but detect)
    chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
    
    # Ensure laravel.log exists
    touch /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    chmod 0666 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
fi

echo "[PASS] Storage self-heal completed"

