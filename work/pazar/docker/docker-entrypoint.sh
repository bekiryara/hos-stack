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

# e) Log-to-stdout hardening: symlink laravel.log to stdout when HOS_LARAVEL_LOG_STDOUT=1
# This ensures Laravel can always write logs even if file permissions fail
# Check if stdout logging is enabled
if [ "${HOS_LARAVEL_LOG_STDOUT:-0}" = "1" ]; then
    # Remove existing laravel.log file if it exists (to avoid conflicts)
    rm -f /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    # Create symlink to stdout (process 1's stdout = container stdout)
    ln -sf /proc/1/fd/1 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    if [ -L /var/www/html/storage/logs/laravel.log ]; then
        echo "[INFO] laravel.log symlinked to stdout (HOS_LARAVEL_LOG_STDOUT=1)" >&2
    else
        echo "[WARN] Failed to symlink laravel.log to stdout; falling back to file" >&2
    fi
fi

# f) Fallback: If symlink fails, ensure regular file exists with permissive permissions
if [ ! -L /var/www/html/storage/logs/laravel.log ]; then
    touch /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    if [ "$(id -u)" -eq 0 ]; then
        chown www-data:www-data /var/www/html/storage/logs/laravel.log 2>/dev/null || true
        # CRITICAL: chmod 0666 for bulletproof append (worker can write even if ownership weird)
        chmod 0666 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    fi
fi

# g) Worker perspective write check (only if symlink failed - skip if symlink exists)
if [ ! -L /var/www/html/storage/logs/laravel.log ]; then
    # Only check if we're using regular file (not symlink)
    if command -v su >/dev/null 2>&1; then
        # Try append as www-data user (worker perspective)
        if ! su -s /bin/sh www-data -c "echo test >> /var/www/html/storage/logs/laravel.log" 2>/dev/null; then
            # Fallback: permissive permissions
            echo "[WARN] Worker write check failed; applying permissive chmod" >&2
            chmod -R 0777 /var/www/html/storage/logs /var/www/html/bootstrap/cache 2>/dev/null || true
            chmod 0666 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
            # Try again
            if ! su -s /bin/sh www-data -c "echo test >> /var/www/html/storage/logs/laravel.log" 2>/dev/null; then
                echo "[FAIL] Worker cannot append to laravel.log even after permissive chmod" >&2
                echo "[HINT] Check named volumes and entrypoint script" >&2
                exit 1
            fi
        fi
    else
        # su missing: fallback to permissive chmod and log warning
        echo "[WARN] su command missing; applying permissive chmod as fallback" >&2
        chmod -R 0777 /var/www/html/storage/logs /var/www/html/bootstrap/cache 2>/dev/null || true
        chmod 0666 /var/www/html/storage/logs/laravel.log 2>/dev/null || true
    fi
else
    # Symlink exists - no need for write check (logs go to stdout/stderr)
    echo "[INFO] laravel.log is symlinked - no permission check needed" >&2
fi

# Execute the original command (supervisord)
exec "$@"

