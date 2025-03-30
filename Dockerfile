FROM php:8.3-fpm

ARG APP_DEBUG
ARG APP_ENV
ARG APP_FAKER_LOCALE
ARG APP_FALLBACK_LOCALE
ARG APP_KEY
ARG APP_LOCALE
ARG APP_MAINTENANCE_DRIVER
ARG APP_NAME
ARG APP_URL
ARG BCRYPT_ROUNDS
ARG CACHE_STORE
ARG DB_CONNECTION
ARG FILESYSTEM_DISK
ARG MAIL_MAILER
ARG PHP_CLI_SERVER_WORKERS
ARG SESSION_DRIVER

RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    unzip \
    git \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libssl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pcntl opcache pdo pdo_mysql intl zip gd exif ftp bcmath \
    && pecl install redis \
    && docker-php-ext-enable redis

COPY php.ini /usr/local/etc/php/conf.d/custom.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache

COPY . .

RUN chown -R www-data:www-data storage bootstrap/cache && \
    chmod -R 775 storage bootstrap/cache

RUN composer install --prefer-dist --optimize-autoloader --no-interaction

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD service nginx start && php-fpm
