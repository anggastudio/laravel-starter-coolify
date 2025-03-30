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

# PHP Configuration
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.jit=tracing" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.jit_buffer_size=256M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "upload_max_filesize=64M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "post_max_size=64M" >> /usr/local/etc/php/conf.d/custom.ini

# Nginx Configuration
RUN echo ' \
user www-data; \
worker_processes auto; \
events { \
    worker_connections 1024; \
} \
http { \
    include /etc/nginx/mime.types; \
    default_type application/octet-stream; \
    access_log /var/log/nginx/access.log; \
    error_log /var/log/nginx/error.log; \
    sendfile on; \
    server { \
        listen 80; \
        server_name localhost; \
        root /var/www/html/public; \
        index index.php; \
        location / { \
            try_files $uri $uri/ /index.php?$query_string; \
        } \
        location ~ \.php$ { \
            fastcgi_split_path_info ^(.+\.php)(/.+)$; \
            fastcgi_pass unix:/var/run/php-fpm.sock; \
            fastcgi_index index.php; \
            include fastcgi_params; \
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \
            fastcgi_param PATH_INFO $fastcgi_path_info; \
        } \
    } \
}' > /etc/nginx/nginx.conf

# Configure PHP-FPM to use Unix socket
RUN echo '[www]' > /usr/local/etc/php-fpm.d/www.conf \
    && echo 'listen = /var/run/php-fpm.sock' >> /usr/local/etc/php-fpm.d/www.conf \
    && echo 'listen.owner = www-data' >> /usr/local/etc/php-fpm.d/www.conf \
    && echo 'listen.group = www-data' >> /usr/local/etc/php-fpm.d/www.conf \
    && echo 'listen.mode = 0660' >> /usr/local/etc/php-fpm.d/www.conf \
    && echo 'user = www-data' >> /usr/local/etc/php-fpm.d/www.conf \
    && echo 'group = www-data' >> /usr/local/etc/php-fpm.d/www.conf

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache

COPY . .

RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 775 storage bootstrap/cache

RUN composer install --prefer-dist --optimize-autoloader --no-interaction

EXPOSE 80

CMD php-fpm -D && nginx -g 'daemon off;'
