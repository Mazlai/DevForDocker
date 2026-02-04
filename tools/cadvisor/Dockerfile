# =============================================================================
# Image cAdvisor personnalisée depuis Ubuntu 24.04
# =============================================================================
# cAdvisor (Container Advisor) fournit des métriques de performance
# et d'utilisation des ressources pour les conteneurs Docker.
# Cette image est construite depuis Ubuntu pour respecter la contrainte
# "0 images depuis Docker Hub" (hors images de base OS).
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="DevForDocker"
LABEL description="cAdvisor - Monitoring des conteneurs Docker personnalisé"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV CADVISOR_VERSION=v0.47.2

# -----------------------------------------------------------------------------
# Installation des dépendances système
# -----------------------------------------------------------------------------
# - wget : téléchargement du binaire cAdvisor
# - ca-certificates : certificats SSL pour HTTPS
# - dmidecode : informations matérielles (utilisé par cAdvisor)
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    dmidecode \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Téléchargement et installation de cAdvisor
# -----------------------------------------------------------------------------
# cAdvisor est distribué sous forme de binaire précompilé sur GitHub.
# -----------------------------------------------------------------------------
RUN wget -q "https://github.com/google/cadvisor/releases/download/${CADVISOR_VERSION}/cadvisor-${CADVISOR_VERSION}-linux-amd64" -O /usr/local/bin/cadvisor \
    && chmod +x /usr/local/bin/cadvisor

# -----------------------------------------------------------------------------
# Script d'entrypoint avec gestion SIGTERM
# -----------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

# Port HTTP pour l'interface web et les métriques
EXPOSE 8080

# Note: STOPSIGNAL SIGTERM est le défaut de Docker, pas besoin de le spécifier
# cAdvisor (Go) gère nativement SIGTERM pour un arrêt propre

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--docker_only=true", "--disable_metrics=percpu,sched,tcp,udp,disk,diskIO,hugetlb,referenced_memory,cpu_topology,resctrl"]
