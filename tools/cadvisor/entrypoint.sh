#!/bin/bash
# =============================================================================
# Entrypoint cAdvisor
# =============================================================================
# Ce script lance cAdvisor en mode foreground via exec.
# cAdvisor (écrit en Go) gère nativement SIGTERM et s'arrête proprement.
# L'utilisation de 'exec' remplace le shell par le processus, permettant
# à Docker d'envoyer les signaux directement au binaire cAdvisor.
# =============================================================================

set -e

echo "[cAdvisor] Démarrage de cAdvisor..."
echo "[cAdvisor] Commande: /usr/local/bin/cadvisor $@"

# exec remplace le processus shell par cadvisor
# SIGTERM est géré nativement par le binaire Go
exec /usr/local/bin/cadvisor "$@"
