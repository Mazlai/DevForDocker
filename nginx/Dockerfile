# =============================================================================
# Image Nginx personnalisée depuis Ubuntu 24.04
# =============================================================================
# Nginx sert de serveur web/reverse proxy pour l'application.
# Il reçoit les requêtes HTTP et les transmet à PHP-FPM pour traitement.
# Construite depuis Ubuntu pour respecter la contrainte "0 images Docker Hub".
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="DevForDocker"
LABEL description="Serveur Web Nginx - Reverse proxy personnalisé"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Installation des dépendances système
# -----------------------------------------------------------------------------
# - nginx : serveur web haute performance
# - curl : nécessaire pour le healthcheck HTTP
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Configuration Nginx
# -----------------------------------------------------------------------------
# - Suppression de la config par défaut
# - Copie de notre configuration personnalisée
# - Configuration en mode foreground (daemon off) pour Docker
# -----------------------------------------------------------------------------
RUN rm -f /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/sites-enabled/default
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

WORKDIR /var/www/html

# -----------------------------------------------------------------------------
# Script d'entrypoint avec gestion SIGTERM
# -----------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

# Port HTTP pour le serveur web
EXPOSE 80

# Signal d'arrêt propre (SIGQUIT pour Nginx = graceful shutdown)
STOPSIGNAL SIGQUIT

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx"]
