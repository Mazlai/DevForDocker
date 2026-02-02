#!/bin/bash
# =============================================================================
# Entrypoint Frontend Angular avec gestion SIGTERM
# =============================================================================
# Ce script assure un arrêt propre du conteneur lors de la réception
# du signal SIGTERM (envoyé par Docker lors d'un docker stop).
# =============================================================================

set -e

# Fonction de gestion du signal SIGTERM
cleanup() {
    echo "[Frontend] Signal SIGTERM reçu, arrêt propre en cours..."
    if [ -n "$SERVER_PID" ]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    echo "[Frontend] Arrêt terminé."
    exit 0
}

# Enregistrement du handler SIGTERM
trap cleanup SIGTERM SIGINT

echo "[Frontend] Démarrage du serveur Angular..."
echo "[Frontend] Arguments: $@"

# Lancement du serveur en arrière-plan pour pouvoir gérer les signaux
exec "$@" &
SERVER_PID=$!

echo "[Frontend] PID: $SERVER_PID"

# Attente de la fin du processus
wait "$SERVER_PID"
