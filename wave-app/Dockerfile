# Utiliser une image officielle PHP avec les extensions requises
FROM php:8.2-fpm

# Installer les dépendances système, extensions PHP
RUN apt-get update && apt-get install -y \
    unzip \
    curl \
    git \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libzip-dev \
    zip \
    libmcrypt-dev \
    libxml2-dev \
    libmagickwand-dev \
    libpq-dev \
    mariadb-client \
    gnupg \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        gd \
        mbstring \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        zip \
        bcmath \
        intl \
        opcache \
        exif \
    && pecl install imagick \
    && docker-php-ext-enable imagick exif \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Installer Node.js et npm (version stable)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm

# Installer Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Définir le répertoire de travail
WORKDIR /var/www/wave

# Copier les fichiers de l'application
COPY ./ . /var/www/wave

# Installer les dépendances backend via Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer install --no-interaction --prefer-dist
RUN chmod -R 777 storage bootstrap/cache
RUN mkdir -p storage/framework/{cache,sessions,views} \
    && chown -R www-data:www-data storage \
    && chmod -R 775 storage


# COPY .env.example .env

# Ajouter un fichier de configuration pour augmenter la mémoire PHP
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/memory-limit.ini

# Exécuter les commandes Artisan avec plus de mémoire
RUN php -d memory_limit=512M artisan optimize:clear
RUN php -d memory_limit=512M artisan optimize
RUN php -d memory_limit=512M artisan key:generate

# Installer les dépendances frontend (optionnel selon votre projet)
# Installer les dépendances NPM (y compris Vite) pour compiler les assets
RUN npm install

# Compiler les assets avec Vite (générer le manifest.json)
RUN npm run build

# Données de production pour Vite (optionnel si vous souhaitez l'exécuter en mode dev)
#RUN npm run dev

# Configurer les permissions
RUN chown -R www-data:www-data /var/www/wave
RUN chmod -R 775 /var/www/wave/storage
RUN chmod -R 775 /var/www/wave/bootstrap/cache

# Configurer l'environnement
RUN php artisan key:generate

# Copier le fichier entrypoint.sh dans l'image Docker et le rendre exécutable
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Définir le script comme le point d'entrée du conteneur
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Exposer les ports pour Nginx et PHP-FPM
EXPOSE 9000

# Définir PHP-FPM comme commande par défaut
CMD ["php-fpm"]
