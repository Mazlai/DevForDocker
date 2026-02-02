#!/bin/bash
# =============================================================================
# Entrypoint cAdvisor avec gestion SIGTERM
# =============================================================================
# Ce script assure un arrêt propre du conteneur lors de la réception
# du signal SIGTERM (envoyé par Docker lors d'un docker stop).
# =============================================================================

set -e

# Fonction de gestion du signal SIGTERM
cleanup() {
    echo "[cAdvisor] Signal SIGTERM reçu, arrêt propre en cours..."
    if [ -n "$CADVISOR_PID" ]; then
        kill -TERM "$CADVISOR_PID" 2>/dev/null || true
        wait "$CADVISOR_PID" 2>/dev/null || true
    fi
    echo "[cAdvisor] Arrêt terminé."
    exit 0
}

# Enregistrement du handler SIGTERM
trap cleanup SIGTERM SIGINT

echo "[cAdvisor] Démarrage de cAdvisor..."
echo "[cAdvisor] Arguments: $@"

# Lancement de cAdvisor en arrière-plan pour pouvoir gérer les signaux
/usr/local/bin/cadvisor "$@" &
CADVISOR_PID=$!

echo "[cAdvisor] PID: $CADVISOR_PID"

# Attente de la fin du processus
wait "$CADVISOR_PID"
