#!/bin/sh
set -e

# Ensure storage directories exist and have correct permissions
# This runs before supervisord starts php-fpm
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache

# Fix ownership (www-data:www-data)
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Fix permissions (ug+rwX = user/group read/write/execute, others read/execute)
chmod -R ug+rwX /var/www/html/storage /var/www/html/bootstrap/cache

# Execute the original command (supervisord)
exec "$@"

