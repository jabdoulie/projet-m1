#!/bin/sh
echo "Démarrage du conteneur..."

# Charger les variables d'environnement du fichier .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Attente que la base de données soit prête
until mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "En attente que la base de données soit prête..."
  sleep 2
done

echo "Base de données prête. Installation de la dépendance doctrine/dbal..."

# Installer la dépendance doctrine/dbal
composer require doctrine/dbal

echo "Dépendance doctrine/dbal installée. Lancement des migrations..."

# Exécuter les migrations
php artisan migrate --force

# Seed des données
php artisan db:seed --force

# Vider les caches de Laravel
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Donner les bonnes permissions si nécessaire
chown -R www-data:www-data /var/www/wave/storage
chmod -R 775 /var/www/wave/storage
chown www-data:www-data /var/www/wave/storage/logs/laravel.log
chmod 664 /var/www/wave/storage/logs/laravel.log
mkdir -p storage/framework/cache
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
chmod -R 775 storage
chown -R www-data:www-data storage
php artisan config:cache


# Lancer le service PHP-FPM
exec php-fpm
