# =============================================================================
# Image Frontend Angular personnalisée depuis Ubuntu 24.04
# =============================================================================
# Cette image contient une application Angular servie via http-server.
# Construite depuis Ubuntu pour respecter la contrainte "0 images Docker Hub".
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="DevForDocker"
LABEL description="Frontend Angular - Application web personnalisée"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Installation des dépendances système
# -----------------------------------------------------------------------------
# - curl, gnupg, ca-certificates : nécessaires pour ajouter le dépôt NodeSource
# - nodejs : runtime JavaScript (inclut npm)
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Installation des outils Node.js globaux
# -----------------------------------------------------------------------------
# - @angular/cli : CLI Angular pour build et développement
# - http-server : serveur HTTP léger pour servir les fichiers statiques
# -----------------------------------------------------------------------------
RUN npm install -g @angular/cli http-server

WORKDIR /app

# Copier le projet Angular
COPY . .

# -----------------------------------------------------------------------------
# Build de l'application Angular
# -----------------------------------------------------------------------------
# - npm install : installe les dépendances du package.json
# - ng build : compile l'application en mode production (optimisé)
# -----------------------------------------------------------------------------
RUN npm install && ng build --configuration=production

# -----------------------------------------------------------------------------
# Script d'entrypoint avec gestion SIGTERM
# -----------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

# Port HTTP pour l'application Angular
EXPOSE 4200

# Note: STOPSIGNAL SIGTERM est le défaut de Docker, pas besoin de le spécifier
# http-server (Node.js) gère nativement SIGTERM pour un arrêt propre

ENTRYPOINT ["/entrypoint.sh"]
CMD ["http-server", "dist/frontend/browser", "-p", "4200", "-c-1"]
