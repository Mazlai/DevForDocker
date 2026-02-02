#!/bin/bash
# =============================================================================
# Entrypoint Backend PHP-FPM avec gestion SIGTERM
# =============================================================================
# Ce script assure un arrêt propre du conteneur lors de la réception
# du signal SIGTERM/SIGQUIT (envoyé par Docker lors d'un docker stop).
# PHP-FPM utilise SIGQUIT pour un arrêt graceful (termine les requêtes en cours).
# =============================================================================

set -e

# Fonction de gestion du signal SIGTERM/SIGQUIT
cleanup() {
    echo "[PHP-FPM] Signal d'arrêt reçu, arrêt graceful en cours..."
    if [ -n "$PHP_PID" ]; then
        # SIGQUIT permet à PHP-FPM de terminer les requêtes en cours
        kill -QUIT "$PHP_PID" 2>/dev/null || true
        wait "$PHP_PID" 2>/dev/null || true
    fi
    echo "[PHP-FPM] Arrêt terminé."
    exit 0
}

# Enregistrement du handler SIGTERM et SIGQUIT
trap cleanup SIGTERM SIGQUIT SIGINT

echo "[PHP-FPM] Démarrage de PHP-FPM 8.3..."
echo "[PHP-FPM] Arguments: $@"

# Lancement de PHP-FPM en arrière-plan pour pouvoir gérer les signaux
"$@" &
PHP_PID=$!

echo "[PHP-FPM] PID: $PHP_PID"

# Attente de la fin du processus
wait "$PHP_PID"
