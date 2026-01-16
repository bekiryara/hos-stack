FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json ./
COPY composer.lock* ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts

FROM php:8.4-fpm-alpine
RUN apk add --no-cache nginx supervisor icu-dev libzip-dev oniguruma-dev postgresql-dev \
  && docker-php-ext-install pdo_pgsql intl zip \
  && rm -rf /var/cache/apk/*

WORKDIR /var/www/html
COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY docker/supervisord.conf /etc/supervisord.conf
COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /run/nginx \
  && mkdir -p storage bootstrap/cache public \
  && echo '<?php' > /var/www/html/public/index.php \
  && echo '' >> /var/www/html/public/index.php \
  && echo 'require __DIR__."/../vendor/autoload.php";' >> /var/www/html/public/index.php \
  && echo '' >> /var/www/html/public/index.php \
  && echo '$app = require_once __DIR__."/../bootstrap/app.php";' >> /var/www/html/public/index.php \
  && echo '' >> /var/www/html/public/index.php \
  && echo '$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);' >> /var/www/html/public/index.php \
  && echo '' >> /var/www/html/public/index.php \
  && echo '$response = $kernel->handle(' >> /var/www/html/public/index.php \
  && echo '    $request = Illuminate\Http\Request::capture()' >> /var/www/html/public/index.php \
  && echo ');' >> /var/www/html/public/index.php \
  && echo '' >> /var/www/html/public/index.php \
  && echo '$response->send();' >> /var/www/html/public/index.php \
  && echo '' >> /var/www/html/public/index.php \
  && echo '$kernel->terminate($request, $response);' >> /var/www/html/public/index.php \
  && printf 'server {\n  listen 80;\n  server_name _;\n  root /var/www/html/public;\n  index index.php index.html;\n\n  access_log /dev/stdout;\n  error_log  /dev/stderr;\n\n  location = /up {\n    access_log off;\n    default_type text/plain;\n    return 200 "ok\\n";\n  }\n\n  location / {\n    try_files $uri $uri/ /index.php?$query_string;\n  }\n\n  location ~ \.php$ {\n    try_files $uri =404;\n    include fastcgi_params;\n    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n    fastcgi_param PATH_INFO $fastcgi_path_info;\n    fastcgi_pass 127.0.0.1:9000;\n  }\n\n  location ~ /\. {\n    deny all;\n  }\n}\n' > /etc/nginx/http.d/default.conf \
  && chown -R www-data:www-data storage bootstrap/cache public \
  && chmod -R ug+rwX storage bootstrap/cache public \
  && chmod +x /usr/local/bin/docker-entrypoint.sh \
  && chmod +x docker/ensure_storage.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
