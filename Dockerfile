# --- Laravel + PHP + Nginx (одна стадия) ---
FROM php:8.3-fpm

# Устанавливаем системные зависимости, PostgreSQL драйверы, Nginx и Supervisor
RUN apt-get update && apt-get install -y \
    git unzip zip curl nginx supervisor libpq-dev \
    libpng-dev libonig-dev libxml2-dev libzip-dev \
    libjpeg62-turbo-dev libfreetype6-dev libicu-dev g++ \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_pgsql pgsql pdo_mysql mbstring exif pcntl bcmath gd zip intl \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Рабочая директория
WORKDIR /app

# Создаём .env чтобы artisan не ругался
RUN echo "APP_ENV=production" > .env

# Копируем весь проект
COPY . .

# Устанавливаем зависимости Laravel
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader

# Копируем конфиги nginx и supervisor
COPY deploy/render/nginx.conf /etc/nginx/conf.d/default.conf
COPY deploy/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deploy/render/entrypoint.sh /entrypoint.sh

# Даём права
RUN chmod +x /entrypoint.sh && chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Кэшируем Laravel (если artisan доступен)
RUN php artisan config:clear || true \
 && php artisan route:clear || true \
 && php artisan view:clear || true

# Render указывает порт через переменную PORT, но по умолчанию 10000
ENV PORT=10000
EXPOSE 10000

# Запуск
CMD ["/entrypoint.sh"]
