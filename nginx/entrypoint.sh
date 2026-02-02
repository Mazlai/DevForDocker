#!/bin/bash
# =============================================================================
# Entrypoint Nginx avec gestion SIGTERM
# =============================================================================
# Ce script assure un arrêt propre du conteneur lors de la réception
# du signal SIGTERM/SIGQUIT (envoyé par Docker lors d'un docker stop).
# Nginx utilise SIGQUIT pour un arrêt graceful (termine les requêtes en cours).
# =============================================================================

set -e

# Fonction de gestion du signal SIGTERM/SIGQUIT
cleanup() {
    echo "[Nginx] Signal d'arrêt reçu, arrêt graceful en cours..."
    if [ -n "$NGINX_PID" ]; then
        # SIGQUIT permet à Nginx de terminer les requêtes en cours
        kill -QUIT "$NGINX_PID" 2>/dev/null || true
        wait "$NGINX_PID" 2>/dev/null || true
    fi
    echo "[Nginx] Arrêt terminé."
    exit 0
}

# Enregistrement du handler SIGTERM et SIGQUIT
trap cleanup SIGTERM SIGQUIT SIGINT

echo "[Nginx] Démarrage de Nginx..."
echo "[Nginx] Arguments: $@"

# Lancement de Nginx en arrière-plan pour pouvoir gérer les signaux
"$@" &
NGINX_PID=$!

echo "[Nginx] PID: $NGINX_PID"

# Attente de la fin du processus
wait "$NGINX_PID"
