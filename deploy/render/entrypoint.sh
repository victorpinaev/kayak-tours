#!/usr/bin/env bash
set -e

# Генерация ключа (если не сгенерирован)
if ! grep -q 'APP_KEY=base64' .env 2>/dev/null; then
  php artisan key:generate --force || true
fi

# Миграции (в проде нужно --force)
php artisan migrate --force || true

# Кеши на прод
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

# Права
chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Старт supervisor (поднимет php-fpm и nginx)
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
