#!/bin/bash
# =============================================================================
# Entrypoint Nginx
# =============================================================================
# Ce script lance Nginx en mode foreground via exec.
# Nginx gère nativement les signaux d'arrêt :
#   - SIGTERM : arrêt rapide (fast shutdown)
#   - SIGQUIT : arrêt graceful (termine les connexions en cours)
# Le Dockerfile définit STOPSIGNAL SIGQUIT pour un arrêt propre.
# =============================================================================

set -e

echo "[Nginx] Démarrage de Nginx..."
echo "[Nginx] Commande: $@"

# exec remplace le processus shell par nginx
# SIGQUIT (défini via STOPSIGNAL) est géré nativement par Nginx
exec "$@"
