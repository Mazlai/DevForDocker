# =============================================================================
# Image Portainer personnalisée depuis Ubuntu 24.04
# =============================================================================
# Portainer est une interface web de gestion Docker.
# Cette image est construite depuis Ubuntu pour respecter la contrainte
# "0 images depuis Docker Hub" (hors images de base OS).
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="DevForDocker"
LABEL description="Portainer CE - Interface de gestion Docker personnalisée"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV PORTAINER_VERSION=2.19.4

# -----------------------------------------------------------------------------
# Installation des dépendances système
# -----------------------------------------------------------------------------
# - wget : téléchargement des binaires Portainer
# - ca-certificates : certificats SSL pour HTTPS
# - tzdata : gestion des fuseaux horaires
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Téléchargement et installation de Portainer
# -----------------------------------------------------------------------------
# Portainer est distribué sous forme de binaire précompilé.
# On télécharge directement depuis GitHub releases.
# -----------------------------------------------------------------------------
RUN wget -q "https://github.com/portainer/portainer/releases/download/${PORTAINER_VERSION}/portainer-${PORTAINER_VERSION}-linux-amd64.tar.gz" -O /tmp/portainer.tar.gz \
    && tar -xzf /tmp/portainer.tar.gz -C /opt/ \
    && rm /tmp/portainer.tar.gz \
    && chmod +x /opt/portainer/portainer

# Créer les répertoires nécessaires
RUN mkdir -p /data

WORKDIR /opt/portainer

# -----------------------------------------------------------------------------
# Script d'entrypoint avec gestion SIGTERM
# -----------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Port HTTPS pour l'interface web
EXPOSE 9443

# Signal d'arrêt propre
STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--bind-https", ":9443", "--data", "/data"]
