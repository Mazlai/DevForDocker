#!/bin/bash
# =============================================================================
# Entrypoint Portainer avec gestion SIGTERM
# =============================================================================
# Ce script assure un arrêt propre du conteneur lors de la réception
# du signal SIGTERM (envoyé par Docker lors d'un docker stop).
# =============================================================================

set -e

# Fonction de gestion du signal SIGTERM
cleanup() {
    echo "[Portainer] Signal SIGTERM reçu, arrêt propre en cours..."
    if [ -n "$PORTAINER_PID" ]; then
        kill -TERM "$PORTAINER_PID" 2>/dev/null || true
        wait "$PORTAINER_PID" 2>/dev/null || true
    fi
    echo "[Portainer] Arrêt terminé."
    exit 0
}

# Enregistrement du handler SIGTERM
trap cleanup SIGTERM SIGINT

echo "[Portainer] Démarrage de Portainer CE..."
echo "[Portainer] Arguments: $@"

# Lancement de Portainer en arrière-plan pour pouvoir gérer les signaux
/opt/portainer/portainer "$@" &
PORTAINER_PID=$!

echo "[Portainer] PID: $PORTAINER_PID"

# Attente de la fin du processus
wait "$PORTAINER_PID"
