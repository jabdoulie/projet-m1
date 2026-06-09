#!/bin/sh
set -e
echo "Démarrage du conteneur..."

# En K8s, DB_* viennent de wave-env / wave-secrets : ne pas écraser avec le .env de l'image (ex. DB_HOST=db).
if [ -z "$DB_HOST" ] && [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# Attente que la base de données soit prête (mariadb-client : --skip-ssl, pas --ssl-mode)
echo "Connexion MySQL vers ${DB_HOST} (user=${DB_USERNAME})..."
db_ready=0
while [ "$db_ready" -eq 0 ]; do
  if mysql --skip-ssl -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SHOW DATABASES;" > /dev/null 2>&1; then
    db_ready=1
  else
    echo "En attente que la base de données soit prête... (host=${DB_HOST})"
    sleep 2
  fi
done

echo "Base de données prête. Installation de la dépendance doctrine/dbal..."
composer require doctrine/dbal

echo "Préparation des répertoires storage..."
mkdir -p storage/logs storage/framework/cache/data storage/framework/sessions storage/framework/views
mkdir -p bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

echo "Lancement des migrations..."
php artisan migrate --force

echo "Seed (uniquement si la base est vide)..."
USER_COUNT=$(mysql --skip-ssl -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USERNAME" -p"$DB_PASSWORD" -N -e "SELECT COUNT(*) FROM users" "$DB_DATABASE" 2>/dev/null || echo "0")
if [ "$USER_COUNT" = "0" ]; then
  php artisan db:seed --force
else
  echo "Utilisateurs déjà présents ($USER_COUNT), seed ignoré."
fi

echo "Nettoyage des caches..."
php artisan config:clear
php artisan cache:clear || echo "WARN: cache:clear a échoué (permissions), on continue."
php artisan route:clear
php artisan view:clear

chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
touch storage/logs/laravel.log
chown www-data:www-data storage/logs/laravel.log
chmod 664 storage/logs/laravel.log

php artisan config:cache

echo "Démarrage de PHP-FPM..."
exec php-fpm
