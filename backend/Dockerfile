# =============================================================================
# Image Backend PHP-FPM personnalisée depuis Ubuntu 24.04
# =============================================================================
# Cette image contient PHP-FPM pour exécuter des scripts PHP.
# PHP-FPM (FastCGI Process Manager) gère les requêtes PHP envoyées par Nginx.
# Construite depuis Ubuntu pour respecter la contrainte "0 images Docker Hub".
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="DevForDocker"
LABEL description="Backend PHP-FPM - Serveur d'application PHP personnalisé"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Installation des dépendances système
# -----------------------------------------------------------------------------
# - php-fpm : FastCGI Process Manager pour PHP
# - php-mysql : extension pour connexion aux bases MySQL/MariaDB
# - php-curl : extension pour requêtes HTTP (APIs externes)
# - php-mbstring : extension pour chaînes multi-octets (UTF-8)
# - php-xml : extension pour manipulation XML/DOM
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    php-fpm \
    php-mysql \
    php-curl \
    php-mbstring \
    php-xml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Configuration du système de fichiers
# -----------------------------------------------------------------------------
# Création du répertoire pour le socket/PID de PHP-FPM
# -----------------------------------------------------------------------------
RUN mkdir -p /run/php

# -----------------------------------------------------------------------------
# Configuration PHP-FPM
# -----------------------------------------------------------------------------
# - listen = 0.0.0.0:9000 : écoute sur toutes les interfaces (port 9000)
#   (remplace le socket Unix par défaut pour communication inter-conteneurs)
# - daemonize = no : PHP-FPM reste en foreground (requis pour Docker)
# -----------------------------------------------------------------------------
RUN sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 0.0.0.0:9000|g' /etc/php/8.3/fpm/pool.d/www.conf \
    && sed -i 's|;daemonize = yes|daemonize = no|g' /etc/php/8.3/fpm/php-fpm.conf

WORKDIR /var/www/html

# -----------------------------------------------------------------------------
# Script d'entrypoint avec gestion SIGTERM
# -----------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Port FastCGI pour communication avec Nginx
EXPOSE 9000

# Signal d'arrêt propre (SIGQUIT pour PHP-FPM = graceful shutdown)
STOPSIGNAL SIGQUIT

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm8.3", "-F"]
