# Image PHP-FPM personnalisée basée sur Ubuntu
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Installer PHP-FPM avec extensions minimales (ajoutez selon vos besoins)
RUN apt-get update && apt-get install -y --no-install-recommends \
    php-fpm \
    php-mysql \
    php-curl \
    php-mbstring \
    php-xml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Créer le répertoire pour PHP-FPM
RUN mkdir -p /run/php

# Configuration PHP-FPM (directives essentielles uniquement)
RUN sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 0.0.0.0:9000|g' /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i 's|;daemonize = yes|daemonize = no|g' /etc/php/8.3/fpm/php-fpm.conf

WORKDIR /var/www/html
EXPOSE 9000
CMD ["php-fpm8.3", "-F"]
