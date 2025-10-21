# --- Build stage (Composer + Node, если надо собрать фронт) ---
FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
    git unzip zip curl libpng-dev libonig-dev libxml2-dev libzip-dev \
    libjpeg62-turbo-dev libfreetype6-dev libonig-dev libicu-dev g++ libpq-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql pdo_pgsql pgsql mbstring exif pcntl bcmath gd zip intl \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
RUN echo "APP_ENV=production" > .env
# Копируем весь код, чтобы artisan был доступен
COPY . .

# Устанавливаем зависимости
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader

# Если есть front и Vite — собери (иначе этот блок можно удалить)
FROM node:20 AS assets
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- Final runtime image (Nginx + PHP-FPM + Supervisor) ---
FROM php:8.3-fpm

# Пакеты, nginx и supervisor
RUN apt-get update && apt-get install -y nginx supervisor \
    && rm -rf /var/lib/apt/lists/*

# PHP ext (нужны и в рантайме)
RUN apt-get update && apt-get install -y \
    libpng-dev libonig-dev libxml2-dev libzip-dev libjpeg62-turbo-dev libfreetype6-dev libicu-dev g++ \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Код приложения
WORKDIR /app
COPY . .
# vendor из build-стадии
COPY --from=phpbase /app/vendor /app/vendor
# публичные ассеты после билда (если собирали)
COPY --from=assets /app/public/build /app/public/build

# Конфиги nginx/supervisor/entrypoint
COPY deploy/render/nginx.conf /etc/nginx/conf.d/default.conf
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Права для Laravel
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Prod-оптимизации
RUN php artisan config:clear || true \
 && php artisan route:clear || true \
 && php artisan view:clear || true

# Render пробрасывает порт через переменную PORT — используем её в nginx.conf
ENV PORT=10000

EXPOSE 10000
CMD ["/entrypoint.sh"]
