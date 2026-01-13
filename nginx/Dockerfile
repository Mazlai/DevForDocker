# Image Nginx personnalisée basée sur Ubuntu
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Installer Nginx et curl (pour healthcheck) depuis les dépôts Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Supprimer la config par défaut
RUN rm -f /etc/nginx/sites-enabled/default

# Copier notre configuration
COPY nginx.conf /etc/nginx/sites-enabled/default

# Configurer Nginx pour tourner en foreground (nécessaire pour Docker)
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

WORKDIR /var/www/html
EXPOSE 80
CMD ["nginx"]
