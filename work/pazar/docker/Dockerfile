FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts

FROM php:8.2-fpm-alpine
RUN apk add --no-cache nginx supervisor icu-dev libzip-dev oniguruma-dev postgresql-dev \
  && docker-php-ext-install pdo_pgsql intl zip \
  && rm -rf /var/cache/apk/*

WORKDIR /var/www/html
COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf
COPY docker/supervisord.conf /etc/supervisord.conf
COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /run/nginx \
  && chown -R www-data:www-data storage bootstrap/cache \
  && chmod -R ug+rwX storage bootstrap/cache \
  && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
