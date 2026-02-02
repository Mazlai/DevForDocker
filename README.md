# 🐳 DevForDocker - Architecture Docker Virtualisée

## 📋 Table des matières
- [Présentation](#-présentation)
- [Architecture](#-architecture)
- [Images Docker](#-images-docker)
  - [Frontend Angular](#1-frontend-angular)
  - [Backend PHP-FPM](#2-backend-php-fpm)
  - [Serveur Web Nginx](#3-serveur-web-nginx)
  - [Portainer](#4-portainer-supervision)
  - [cAdvisor](#5-cadvisor-monitoring)
- [Orchestration Docker Compose](#-orchestration-docker-compose)
- [Gestion des Signaux SIGTERM](#-gestion-des-signaux-sigterm)
- [Démarrage Rapide](#-démarrage-rapide)

---

## 🎯 Présentation

Ce projet met en place une architecture virtualisée basée sur Docker, comprenant :
- **Frontend** : Application Angular
- **Backend** : API PHP-FPM
- **Serveur Web** : Nginx (reverse proxy)
- **Outils de supervision** : Portainer et cAdvisor

**Contrainte respectée** : Toutes les images sont personnalisées et construites depuis `ubuntu:24.04` (aucune image prête à l'emploi depuis Docker Hub).

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RÉSEAU: app-network                            │
│                                (bridge)                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │   FRONTEND   │     │    NGINX     │     │   PHP-FPM    │                │
│  │   (Angular)  │     │  (Reverse    │────▶│   (Backend)  │                │
│  │              │     │   Proxy)     │     │              │                │
│  │  Port: 4200  │     │  Port: 8080  │     │  Port: 9000  │                │
│  │              │     │              │     │  (interne)   │                │
│  └──────────────┘     └──────────────┘     └──────────────┘                │
│         │                    │                    │                         │
│         │                    │                    │                         │
│         └────────────────────┼────────────────────┘                         │
│                              │                                               │
│  ┌──────────────┐     ┌──────────────┐                                      │
│  │  PORTAINER   │     │   cADVISOR   │                                      │
│  │ (Gestion     │     │ (Monitoring) │                                      │
│  │  Docker)     │     │              │                                      │
│  │              │     │              │                                      │
│  │ Port: 9443   │     │  Port: 8081  │                                      │
│  │   (HTTPS)    │     │   (HTTP)     │                                      │
│  └──────────────┘     └──────────────┘                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

                              HÔTE DOCKER
┌─────────────────────────────────────────────────────────────────────────────┐
│  Ports exposés :                                                            │
│  • http://localhost:4200  → Frontend Angular                                │
│  • http://localhost:8080  → Backend PHP (via Nginx)                         │
│  • https://localhost:9443 → Portainer (interface Docker)                    │
│  • http://localhost:8081  → cAdvisor (métriques)                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Flux de communication

```
┌────────────┐    HTTP     ┌────────────┐   FastCGI   ┌────────────┐
│            │  :8080/80   │            │    :9000    │            │
│   Client   │────────────▶│   Nginx    │────────────▶│  PHP-FPM   │
│            │             │            │             │            │
└────────────┘             └────────────┘             └────────────┘
                                 │
                                 │ /var/www/html (volume partagé)
                                 │
                           ┌─────┴─────┐
                           │  Backend  │
                           │   Source  │
                           └───────────┘
```

---

## 📦 Images Docker

### 1. Frontend Angular

**Fichier** : `frontend/Dockerfile`

#### Dépendances installées

| Package | Rôle |
|---------|------|
| `curl` | Téléchargement de ressources (ajout dépôt NodeSource) |
| `gnupg` | Gestion des clés GPG pour authentifier les dépôts |
| `ca-certificates` | Certificats SSL pour connexions HTTPS sécurisées |
| `nodejs` (v20.x) | Runtime JavaScript pour exécuter Angular CLI |

#### Outils Node.js globaux

| Package | Rôle |
|---------|------|
| `@angular/cli` | CLI officiel Angular pour build et développement |
| `http-server` | Serveur HTTP léger pour servir les fichiers statiques |

#### Manipulations sur l'OS

1. **Ajout du dépôt NodeSource** :
   ```bash
   curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
   echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
   ```
   → Permet d'installer Node.js 20.x (LTS) au lieu de la version Ubuntu (plus ancienne)

2. **Nettoyage des caches** :
   ```bash
   apt-get clean && rm -rf /var/lib/apt/lists/*
   ```
   → Réduit la taille de l'image finale

3. **Build Angular en production** :
   ```bash
   ng build --configuration=production
   ```
   → Compile et optimise l'application (minification, tree-shaking)

#### Arguments au run

| Argument | Valeur par défaut | Description |
|----------|-------------------|-------------|
| Port HTTP | `4200` | Port d'écoute du serveur HTTP |
| Cache | `-c-1` | Désactive le cache (développement) |

#### Entrypoint

Le script `entrypoint.sh` :
- Intercepte les signaux `SIGTERM` et `SIGINT`
- Lance `http-server` en arrière-plan
- Attend la fin du processus pour un arrêt propre

---

### 2. Backend PHP-FPM

**Fichier** : `backend/Dockerfile`

#### Dépendances installées

| Package | Rôle |
|---------|------|
| `php-fpm` | FastCGI Process Manager - gère les requêtes PHP |
| `php-mysql` | Extension pour connexion MySQL/MariaDB |
| `php-curl` | Extension pour requêtes HTTP (APIs REST) |
| `php-mbstring` | Support des chaînes multi-octets (UTF-8, emojis) |
| `php-xml` | Manipulation de documents XML/DOM |

#### Manipulations sur l'OS

1. **Création du répertoire runtime** :
   ```bash
   mkdir -p /run/php
   ```
   → Répertoire pour le fichier PID de PHP-FPM

2. **Configuration de l'écoute réseau** :
   ```bash
   sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 0.0.0.0:9000|g' /etc/php/8.3/fpm/pool.d/www.conf
   ```
   → Remplace le socket Unix par une écoute TCP sur le port 9000
   → Nécessaire pour la communication entre conteneurs Docker

3. **Désactivation du mode daemon** :
   ```bash
   sed -i 's|;daemonize = yes|daemonize = no|g' /etc/php/8.3/fpm/php-fpm.conf
   ```
   → PHP-FPM reste en foreground (requis pour Docker)
   → Permet à Docker de surveiller le processus principal

#### Arguments au run

| Argument | Valeur | Description |
|----------|--------|-------------|
| `-F` | - | Force le mode foreground |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `9000` | FastCGI | Communication avec Nginx (interne au réseau Docker) |

#### Entrypoint

Le script `entrypoint.sh` :
- Intercepte `SIGTERM`, `SIGQUIT` et `SIGINT`
- Utilise `SIGQUIT` pour un arrêt graceful (termine les requêtes en cours)
- Affiche les logs de démarrage

---

### 3. Serveur Web Nginx

**Fichier** : `nginx/Dockerfile`

#### Dépendances installées

| Package | Rôle |
|---------|------|
| `nginx` | Serveur web haute performance / reverse proxy |
| `curl` | Utilisé pour le healthcheck HTTP |

#### Manipulations sur l'OS

1. **Suppression de la config par défaut** :
   ```bash
   rm -f /etc/nginx/sites-enabled/default
   ```
   → Évite les conflits avec notre configuration

2. **Copie de la configuration personnalisée** :
   ```bash
   COPY nginx.conf /etc/nginx/sites-enabled/default
   ```
   → Configuration pour proxy vers PHP-FPM

3. **Mode foreground** :
   ```bash
   echo "daemon off;" >> /etc/nginx/nginx.conf
   ```
   → Nginx reste en foreground pour Docker

#### Configuration Nginx (`nginx.conf`)

```nginx
server {
    listen 80;                          # Écoute sur le port 80
    server_name localhost;
    root /var/www/html;                 # Répertoire des fichiers PHP
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php-fpm:9000;      # Proxy vers le conteneur PHP-FPM
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `80` | HTTP | Requêtes web entrantes |

#### Entrypoint

Le script `entrypoint.sh` :
- Intercepte `SIGTERM`, `SIGQUIT` et `SIGINT`
- Utilise `SIGQUIT` pour un arrêt graceful Nginx
- Permet de terminer les connexions en cours avant arrêt

---

### 4. Portainer (Supervision)

**Fichier** : `tools/portainer/Dockerfile`

#### Dépendances installées

| Package | Rôle |
|---------|------|
| `wget` | Téléchargement du binaire Portainer |
| `ca-certificates` | Certificats SSL pour HTTPS |
| `tzdata` | Gestion des fuseaux horaires |

#### Manipulations sur l'OS

1. **Téléchargement de Portainer** :
   ```bash
   wget "https://github.com/portainer/portainer/releases/download/${PORTAINER_VERSION}/portainer-${PORTAINER_VERSION}-linux-amd64.tar.gz"
   tar -xzf /tmp/portainer.tar.gz -C /opt/
   chmod +x /opt/portainer/portainer
   ```
   → Installation du binaire Portainer depuis GitHub releases

2. **Création du répertoire data** :
   ```bash
   mkdir -p /data
   ```
   → Stockage des données persistantes de Portainer

#### Arguments au run

| Argument | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `--bind-https` | `:9443` | Port HTTPS de l'interface web |
| `--data` | `/data` | Répertoire de données persistantes |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `9443` | HTTPS | Interface web de gestion Docker |

#### Volumes requis

| Volume | Mode | Usage |
|--------|------|-------|
| `/var/run/docker.sock` | RW | Communication avec le daemon Docker |
| `portainer_data:/data` | RW | Persistance des données |

---

### 5. cAdvisor (Monitoring)

**Fichier** : `tools/cadvisor/Dockerfile`

#### Dépendances installées

| Package | Rôle |
|---------|------|
| `wget` | Téléchargement du binaire cAdvisor |
| `ca-certificates` | Certificats SSL |
| `dmidecode` | Informations matérielles système |

#### Manipulations sur l'OS

1. **Téléchargement de cAdvisor** :
   ```bash
   wget "https://github.com/google/cadvisor/releases/download/${CADVISOR_VERSION}/cadvisor-${CADVISOR_VERSION}-linux-amd64" -O /usr/local/bin/cadvisor
   chmod +x /usr/local/bin/cadvisor
   ```
   → Installation du binaire cAdvisor depuis GitHub releases

#### Arguments au run

| Argument | Description |
|----------|-------------|
| `--docker_only=true` | Surveille uniquement les conteneurs Docker |
| `--disable_metrics=...` | Désactive les métriques non nécessaires pour réduire l'overhead |

**Métriques désactivées** :
- `percpu` : Métriques par CPU
- `sched` : Métriques de scheduling
- `tcp`, `udp` : Métriques réseau détaillées
- `disk`, `diskIO` : Métriques disque
- `hugetlb` : Pages mémoire larges
- `referenced_memory` : Mémoire référencée
- `cpu_topology` : Topologie CPU
- `resctrl` : Resource control

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `8080` | HTTP | Interface web et métriques Prometheus |

#### Volumes requis

| Volume | Mode | Usage |
|--------|------|-------|
| `/:/rootfs` | RO | Accès au système de fichiers hôte |
| `/var/run` | RO | Socket Docker et autres sockets |
| `/sys` | RO | Informations système (cgroups) |
| `/var/lib/docker/` | RO | Données des conteneurs Docker |

---

## 🎼 Orchestration Docker Compose

### Variables d'environnement

Les ressources sont configurables via des variables d'environnement :

| Variable | Défaut | Service | Description |
|----------|--------|---------|-------------|
| `FRONTEND_MEMORY_LIMIT` | `512m` | Frontend | Limite mémoire |
| `FRONTEND_CPU_LIMIT` | `0.5` | Frontend | Limite CPU (50%) |
| `BACKEND_MEMORY_LIMIT` | `256m` | PHP-FPM | Limite mémoire |
| `BACKEND_CPU_LIMIT` | `0.5` | PHP-FPM | Limite CPU (50%) |
| `SERVER_MEMORY_LIMIT` | `128m` | Nginx | Limite mémoire |
| `SERVER_CPU_LIMIT` | `0.25` | Nginx | Limite CPU (25%) |
| `PORTAINER_MEMORY_LIMIT` | `256m` | Portainer | Limite mémoire |
| `PORTAINER_CPU_LIMIT` | `0.25` | Portainer | Limite CPU (25%) |
| `CADVISOR_MEMORY_LIMIT` | `128m` | cAdvisor | Limite mémoire |
| `CADVISOR_CPU_LIMIT` | `0.25` | cAdvisor | Limite CPU (25%) |

### Justification des limites de ressources

| Service | Mémoire | CPU | Justification |
|---------|---------|-----|---------------|
| **Frontend** | 512 Mo | 50% | Application Angular servie statiquement, http-server est léger |
| **PHP-FPM** | 256 Mo | 50% | Pool de workers PHP, dépend de la charge applicative |
| **Nginx** | 128 Mo | 25% | Reverse proxy léger, peu de traitement |
| **Portainer** | 256 Mo | 25% | Interface web Go, requiert plus de mémoire |
| **cAdvisor** | 128 Mo | 25% | Collecte de métriques, overhead minimal |

### Ordre de démarrage (depends_on)

```
┌────────────┐
│  php-fpm   │ ◄── Démarre en premier
└─────┬──────┘
      │ condition: service_healthy
      ▼
┌────────────┐
│   nginx    │ ◄── Attend que PHP-FPM soit healthy
└─────┬──────┘
      │ condition: service_healthy
      ▼
┌────────────┐
│ portainer  │ ◄── Attend que Nginx soit healthy
└─────┬──────┘
      │ condition: service_started
      ▼
┌────────────┐
│  cadvisor  │ ◄── Démarre en dernier
└────────────┘

┌────────────┐
│  frontend  │ ◄── Indépendant (aucune dépendance)
└────────────┘
```

**Pourquoi cet ordre ?**
1. **PHP-FPM d'abord** : Le backend doit être prêt avant Nginx
2. **Nginx ensuite** : Le serveur web a besoin de PHP-FPM
3. **Portainer après** : Supervision après que l'app principale soit up
4. **cAdvisor en dernier** : Monitoring après tout le reste
5. **Frontend indépendant** : Pas de dépendance côté serveur

### Healthchecks

| Service | Test | Interval | Timeout | Retries |
|---------|------|----------|---------|---------|
| PHP-FPM | `php-fpm8.3 -t` | 30s | 10s | 3 |
| Nginx | `curl -f http://localhost/` | 30s | 10s | 3 |

---

## 🛑 Gestion des Signaux SIGTERM

Chaque service dispose d'un script `entrypoint.sh` qui gère proprement les signaux d'arrêt :

### Mécanisme

```bash
# Fonction de nettoyage
cleanup() {
    echo "[Service] Signal reçu, arrêt propre..."
    kill -TERM "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    exit 0
}

# Enregistrement du trap
trap cleanup SIGTERM SIGINT

# Lancement en background
command &
PID=$!

# Attente
wait "$PID"
```

### Signaux par service

| Service | Signal d'arrêt | Comportement |
|---------|----------------|--------------|
| Frontend | `SIGTERM` | Arrêt immédiat de http-server |
| PHP-FPM | `SIGQUIT` | Arrêt graceful (termine les requêtes) |
| Nginx | `SIGQUIT` | Arrêt graceful (termine les connexions) |
| Portainer | `SIGTERM` | Arrêt standard |
| cAdvisor | `SIGTERM` | Arrêt standard |

### Pourquoi c'est important ?

- **Évite la perte de données** : Les requêtes en cours sont terminées
- **Arrêt propre** : Pas de processus zombie
- **Respect du timeout Docker** : Évite le `SIGKILL` forcé après 10s

---

## 🚀 Démarrage Rapide

### Prérequis

- Docker Engine 20.10+
- Docker Compose v2+

### Lancement

```bash
# Cloner le projet
git clone https://github.com/Mazlai/DevForDocker.git
cd DevForDocker

# Lancer tous les services
docker-compose up -d --build

# Avec des limites personnalisées
FRONTEND_MEMORY_LIMIT=1g BACKEND_CPU_LIMIT=1 docker-compose up -d --build
```

### Accès aux services

| Service | URL |
|---------|-----|
| Frontend Angular | http://localhost:4200 |
| Backend PHP | http://localhost:8080 |
| Portainer | https://localhost:9443 |
| cAdvisor | http://localhost:8081 |

### Commandes utiles

```bash
# Voir les logs
docker-compose logs -f

# Voir l'état des conteneurs
docker-compose ps

# Arrêter les services
docker-compose down

# Arrêter et supprimer les volumes
docker-compose down -v

# Reconstruire un service spécifique
docker-compose up -d --build nginx
```

---

## 📄 Licence

Ce projet est fourni à des fins éducatives.

---

*Documentation générée pour le projet DevForDocker - Février 2026*
