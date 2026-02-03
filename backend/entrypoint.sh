#!/bin/bash
# =============================================================================
# Entrypoint Backend PHP-FPM
# =============================================================================
# Ce script lance PHP-FPM en mode foreground via exec.
# PHP-FPM gère nativement les signaux d'arrêt :
#   - SIGTERM : arrêt immédiat
#   - SIGQUIT : arrêt graceful (termine les requêtes en cours avant de s'arrêter)
# Le Dockerfile définit STOPSIGNAL SIGQUIT pour un arrêt propre.
# =============================================================================

set -e

echo "[PHP-FPM] Démarrage de PHP-FPM 8.3..."
echo "[PHP-FPM] Commande: $@"

# exec remplace le processus shell par php-fpm
# SIGQUIT (défini via STOPSIGNAL) est géré nativement par PHP-FPM
exec "$@"
