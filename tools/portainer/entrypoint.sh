#!/bin/bash
# =============================================================================
# Entrypoint Portainer
# =============================================================================
# Ce script lance Portainer en mode foreground via exec.
# Portainer (écrit en Go) gère nativement SIGTERM et s'arrête proprement.
# L'utilisation de 'exec' remplace le shell par le processus, permettant
# à Docker d'envoyer les signaux directement au binaire Portainer.
# =============================================================================

set -e

echo "[Portainer] Démarrage de Portainer CE..."
echo "[Portainer] Commande: /opt/portainer/portainer $@"

# exec remplace le processus shell par portainer
# SIGTERM est géré nativement par le binaire Go
exec /opt/portainer/portainer "$@"
