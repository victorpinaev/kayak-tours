#!/usr/bin/env bash
set -e

# Генерируем ключ, если не установлен
if ! grep -q 'APP_KEY=base64' .env 2>/dev/null; then
  php artisan key:generate --force || true
fi

# Выполняем миграции
php artisan migrate --force || true

# Кэшируем Laravel
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

# Права
chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Запускаем PHP-FPM и Nginx через Supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
