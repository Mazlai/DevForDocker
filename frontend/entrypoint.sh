#!/bin/bash
# =============================================================================
# Entrypoint Frontend Angular
# =============================================================================
# Ce script lance http-server en mode foreground via exec.
# http-server (Node.js) gère nativement SIGTERM et s'arrête proprement.
# L'utilisation de 'exec' remplace le shell par le processus, permettant
# à Docker d'envoyer les signaux directement au processus principal.
# =============================================================================

set -e

echo "[Frontend] Démarrage du serveur Angular..."
echo "[Frontend] Commande: $@"

# exec remplace le processus shell par http-server
# Les signaux SIGTERM sont ainsi reçus directement par http-server
exec "$@"
