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

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Respecte la contrainte "0 images Docker Hub prêtes à l'emploi". Ubuntu LTS offre stabilité et support long terme. |
| **Node.js 20.x LTS** | Version LTS (Long Term Support) stable pour production, compatibilité Angular garantie. |
| **Build en mode production** | `ng build --configuration=production` génère des fichiers optimisés (minification, tree-shaking, AOT compilation). |
| **http-server au lieu de ng serve** | `ng serve` est pour le développement uniquement. `http-server` est léger et adapté pour servir des fichiers statiques en production. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `curl` | Téléchargement HTTP | Nécessaire pour récupérer la clé GPG du dépôt NodeSource |
| `gnupg` | Gestion des clés GPG | Authentifie le dépôt NodeSource pour éviter les attaques MITM |
| `ca-certificates` | Certificats SSL racine | Permet les connexions HTTPS sécurisées (npm, dépôts) |
| `nodejs` (v20.x) | Runtime JavaScript | Exécute Angular CLI et http-server |
| `@angular/cli` (npm global) | CLI Angular | Compile l'application Angular |
| `http-server` (npm global) | Serveur HTTP statique | Sert les fichiers buildés sans overhead |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Création du keyring** | `mkdir -p /etc/apt/keyrings` | Répertoire sécurisé pour stocker les clés GPG des dépôts tiers |
| **Import clé GPG NodeSource** | `curl ... \| gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg` | Convertit la clé ASCII en format binaire pour apt |
| **Ajout dépôt NodeSource** | `echo "deb [signed-by=...] ..." \| tee /etc/apt/sources.list.d/nodesource.list` | Ajoute le dépôt officiel Node.js (version récente vs Ubuntu par défaut) |
| **Nettoyage cache apt** | `apt-get clean && rm -rf /var/lib/apt/lists/*` | Réduit la taille de l'image finale (~100 Mo économisés) |
| **Installation dépendances npm** | `npm install` | Installe les dépendances définies dans package.json |
| **Build production** | `ng build --configuration=production` | Compile TypeScript → JavaScript optimisé dans `dist/` |

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `http-server` | - | Binaire du serveur HTTP |
| `dist/frontend/browser` | - | Répertoire contenant les fichiers Angular compilés |
| `-p 4200` | Port 4200 | Port d'écoute du serveur HTTP |
| `-c-1` | Cache désactivé | `-c-1` désactive le cache HTTP (utile pour le dev, peut être changé en prod) |

#### Entrypoint

```bash
exec "$@"
```

**Pourquoi `exec` ?** 
- `exec` remplace le processus shell (PID 1) par `http-server`
- Docker envoie SIGTERM directement à `http-server` (pas au shell)
- `http-server` (Node.js) gère nativement SIGTERM et s'arrête proprement
- Pas besoin de trap manuel car le processus reçoit directement les signaux

---

### 2. Backend PHP-FPM

**Fichier** : `backend/Dockerfile`

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Cohérence avec les autres images, Ubuntu 24.04 inclut PHP 8.3 nativement. |
| **PHP-FPM au lieu de mod_php** | FPM (FastCGI Process Manager) est plus performant et permet de séparer le serveur web du moteur PHP. |
| **Écoute TCP au lieu de socket Unix** | Les sockets Unix ne fonctionnent pas entre conteneurs. TCP sur le port 9000 permet la communication réseau Docker. |
| **Mode foreground (`daemonize = no`)** | Docker attend un processus en foreground. Si PHP-FPM se daemonise, Docker pense que le conteneur s'est arrêté. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `php-fpm` | FastCGI Process Manager | Gère un pool de workers PHP pour traiter les requêtes |
| `php-mysql` | Extension PDO MySQL | Connexion aux bases de données MySQL/MariaDB |
| `php-curl` | Extension cURL | Requêtes HTTP vers des APIs externes |
| `php-mbstring` | Extension Multibyte String | Support UTF-8 complet (caractères spéciaux, emojis) |
| `php-xml` | Extension XML/DOM | Parsing et génération de documents XML |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Création répertoire runtime** | `mkdir -p /run/php` | PHP-FPM stocke son fichier PID dans ce répertoire |
| **Configuration écoute réseau** | `sed -i 's\|listen = /run/php/php.*-fpm.sock\|listen = 0.0.0.0:9000\|g' /etc/php/8.3/fpm/pool.d/www.conf` | Remplace le socket Unix par une écoute TCP sur toutes les interfaces, port 9000 |
| **Désactivation mode daemon** | `sed -i 's\|;daemonize = yes\|daemonize = no\|g' /etc/php/8.3/fpm/php-fpm.conf` | PHP-FPM reste en foreground pour que Docker puisse le superviser |
| **Nettoyage cache apt** | `apt-get clean && rm -rf /var/lib/apt/lists/*` | Réduit la taille de l'image finale |

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `php-fpm8.3` | - | Binaire PHP-FPM version 8.3 |
| `-F` | Force foreground | Redondant avec la config mais garantit le mode foreground |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `9000` | FastCGI | Communication avec Nginx (interne au réseau Docker uniquement) |

#### Entrypoint

```bash
exec "$@"
```

**Pourquoi `exec` avec STOPSIGNAL SIGQUIT ?**
- PHP-FPM gère nativement plusieurs signaux :
  - `SIGTERM` : Arrêt immédiat (peut couper des requêtes en cours)
  - `SIGQUIT` : Arrêt graceful (attend la fin des requêtes avant de s'arrêter)
- Le Dockerfile définit `STOPSIGNAL SIGQUIT` pour un arrêt propre
- `exec` transmet directement SIGQUIT à PHP-FPM

---

### 3. Serveur Web Nginx

**Fichier** : `nginx/Dockerfile`

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Cohérence et version récente de Nginx (1.24+). |
| **Nginx comme reverse proxy** | Nginx excelle pour servir des fichiers statiques et proxifier vers PHP-FPM via FastCGI. |
| **Mode foreground (`daemon off`)** | Même raison que PHP-FPM : Docker nécessite un processus en foreground. |
| **Suppression config par défaut** | Évite les conflits avec notre configuration personnalisée. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `nginx` | Serveur web haute performance | Reverse proxy vers PHP-FPM, serveur de fichiers statiques |
| `curl` | Client HTTP | Utilisé par le healthcheck pour vérifier que Nginx répond |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Suppression config par défaut** | `rm -f /etc/nginx/sites-enabled/default` | La config Ubuntu par défaut écoute sur le port 80 avec une page "Welcome to nginx" |
| **Copie config personnalisée** | `COPY nginx.conf /etc/nginx/sites-enabled/default` | Notre config définit le proxy FastCGI vers PHP-FPM |
| **Mode foreground** | `echo "daemon off;" >> /etc/nginx/nginx.conf` | Ajoute la directive pour empêcher Nginx de se daemoniser |
| **Nettoyage cache apt** | `apt-get clean && rm -rf /var/lib/apt/lists/*` | Réduit la taille de l'image |

#### Configuration Nginx (`nginx.conf`)

```nginx
server {
    listen 80;                          # Écoute sur le port 80 (HTTP)
    server_name localhost;
    root /var/www/html;                 # Répertoire des fichiers PHP
    index index.php index.html;         # Fichiers index par défaut

    location / {
        try_files $uri $uri/ /index.php?$query_string;  # Réécriture d'URL
    }

    location ~ \.php$ {
        fastcgi_pass php-fpm:9000;      # Proxy vers le conteneur PHP-FPM (nom DNS Docker)
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;         # Paramètres FastCGI standards
    }
}
```

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `nginx` | - | Lance Nginx (en foreground grâce à `daemon off;`) |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `80` | HTTP | Requêtes web entrantes (mappé sur 8080 côté hôte) |

#### Entrypoint

```bash
exec "$@"
```

**Pourquoi `exec` avec STOPSIGNAL SIGQUIT ?**
- Nginx gère nativement :
  - `SIGTERM` : Arrêt rapide (fast shutdown)
  - `SIGQUIT` : Arrêt graceful (termine les connexions actives)
- Le Dockerfile définit `STOPSIGNAL SIGQUIT`
- `exec` assure que Nginx est PID 1 et reçoit directement les signaux

---

### 4. Portainer (Supervision)

**Fichier** : `tools/portainer/Dockerfile`

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Respecte la contrainte. Portainer est un binaire Go statique, l'OS importe peu. |
| **Téléchargement depuis GitHub Releases** | Portainer est distribué sous forme de binaire précompilé, pas besoin de compiler. |
| **Version fixée (2.19.4)** | Reproductibilité des builds, évite les surprises lors de mises à jour. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `wget` | Téléchargement HTTP | Récupère l'archive Portainer depuis GitHub |
| `ca-certificates` | Certificats SSL | Nécessaire pour HTTPS (GitHub, et l'interface Portainer) |
| `tzdata` | Fuseaux horaires | Portainer affiche des timestamps, tzdata assure le bon fuseau |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Téléchargement Portainer** | `wget -q "https://github.com/.../portainer-...-linux-amd64.tar.gz"` | Récupère l'archive officielle |
| **Extraction archive** | `tar -xzf /tmp/portainer.tar.gz -C /opt/` | Extrait dans /opt/portainer/ |
| **Permissions exécution** | `chmod +x /opt/portainer/portainer` | Rend le binaire exécutable |
| **Création répertoire data** | `mkdir -p /data` | Stockage persistant des configurations Portainer |
| **Nettoyage** | `rm /tmp/portainer.tar.gz` | Supprime l'archive pour réduire la taille de l'image |

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `--bind-https` | `:9443` | Portainer écoute en HTTPS sur le port 9443 |
| `--data` | `/data` | Répertoire où Portainer stocke sa base de données (utilisateurs, configs) |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `9443` | HTTPS | Interface web de gestion Docker (certificat auto-signé) |

#### Volumes requis

| Volume | Mode | Pourquoi ? |
|--------|------|------------|
| `/var/run/docker.sock` | RW | Socket Docker : permet à Portainer de communiquer avec le daemon Docker |
| `portainer_data:/data` | RW | Persistance des données (sinon perdues au redémarrage) |

#### Entrypoint

```bash
exec /opt/portainer/portainer "$@"
```

**Pourquoi `exec` ?**
- Portainer est écrit en Go et gère nativement SIGTERM
- `exec` assure que Portainer est PID 1
- Arrêt propre automatique sans trap manuel

---

### 5. cAdvisor (Monitoring)

**Fichier** : `tools/cadvisor/Dockerfile`

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Respecte la contrainte. cAdvisor est un binaire Go statique. |
| **Téléchargement depuis GitHub Releases** | Binaire précompilé officiel de Google. |
| **Version fixée (v0.47.2)** | Reproductibilité et stabilité. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `wget` | Téléchargement HTTP | Récupère le binaire cAdvisor depuis GitHub |
| `ca-certificates` | Certificats SSL | Connexions HTTPS (GitHub) |
| `dmidecode` | Infos matérielles | cAdvisor l'utilise pour récupérer des informations sur le hardware |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Téléchargement cAdvisor** | `wget -q "https://github.com/.../cadvisor-...-linux-amd64" -O /usr/local/bin/cadvisor` | Télécharge directement dans le PATH |
| **Permissions exécution** | `chmod +x /usr/local/bin/cadvisor` | Rend le binaire exécutable |
| **Nettoyage cache apt** | `apt-get clean && rm -rf /var/lib/apt/lists/*` | Réduit la taille de l'image |

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `--docker_only=true` | - | Ne surveille que les conteneurs Docker (ignore les autres cgroups) |
| `--disable_metrics=...` | Voir ci-dessous | Désactive les métriques non nécessaires pour réduire l'overhead CPU/mémoire |

**Métriques désactivées et pourquoi :**

| Métrique | Raison de la désactivation |
|----------|---------------------------|
| `percpu` | Détail par CPU inutile pour notre cas |
| `sched` | Métriques de scheduling kernel avancées |
| `tcp`, `udp` | Métriques réseau détaillées (trop verbeux) |
| `disk`, `diskIO` | Métriques disque (non pertinent pour nos conteneurs) |
| `hugetlb` | Pages mémoire larges (usage avancé kernel) |
| `referenced_memory` | Mémoire référencée (détail excessif) |
| `cpu_topology` | Topologie CPU (non pertinent) |
| `resctrl` | Resource control (fonctionnalité Intel avancée) |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `8080` | HTTP | Interface web et endpoint métriques Prometheus (mappé sur 8081 côté hôte) |

#### Volumes requis

| Volume | Mode | Pourquoi ? |
|--------|------|------------|
| `/:/rootfs` | RO (lecture seule) | Accès au système de fichiers hôte pour les métriques |
| `/var/run` | RO | Socket Docker et autres sockets système |
| `/sys` | RO | Informations système (cgroups, métriques kernel) |
| `/var/lib/docker/` | RO | Données des conteneurs (layers, métadonnées) |

#### Entrypoint

```bash
exec /usr/local/bin/cadvisor "$@"
```

**Pourquoi `exec` ?**
- cAdvisor est écrit en Go et gère nativement SIGTERM
- `exec` assure que cAdvisor est PID 1
- Arrêt propre automatique

---

## 🎼 Orchestration Docker Compose

### Variables d'environnement

Les ressources sont configurables via le fichier `.env` ou des variables d'environnement :
- Affiche les logs de démarrage

---

### 3. Serveur Web Nginx

**Fichier** : `nginx/Dockerfile`

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Cohérence et version récente de Nginx (1.24+). |
| **Nginx comme reverse proxy** | Nginx excelle pour servir des fichiers statiques et proxifier vers PHP-FPM via FastCGI. |
| **Mode foreground (`daemon off`)** | Docker nécessite un processus en foreground pour surveiller le conteneur. |
| **Suppression config par défaut** | Évite les conflits avec notre configuration personnalisée. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `nginx` | Serveur web haute performance | Reverse proxy vers PHP-FPM, serveur de fichiers statiques |
| `curl` | Client HTTP | Utilisé par le healthcheck pour vérifier que Nginx répond |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Suppression config par défaut** | `rm -f /etc/nginx/sites-enabled/default` | La config Ubuntu par défaut affiche une page "Welcome to nginx" |
| **Copie config personnalisée** | `COPY nginx.conf /etc/nginx/sites-enabled/default` | Notre config définit le proxy FastCGI vers PHP-FPM |
| **Mode foreground** | `echo "daemon off;" >> /etc/nginx/nginx.conf` | Empêche Nginx de se daemoniser |
| **Nettoyage cache apt** | `apt-get clean && rm -rf /var/lib/apt/lists/*` | Réduit la taille de l'image |

#### Configuration Nginx (`nginx.conf`)

```nginx
server {
    listen 80;                          # Écoute sur le port 80 (HTTP)
    server_name localhost;
    root /var/www/html;                 # Répertoire des fichiers PHP
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php-fpm:9000;      # Proxy vers le conteneur PHP-FPM (nom DNS Docker)
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `nginx` | - | Lance Nginx (en foreground grâce à `daemon off;`) |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `80` | HTTP | Requêtes web entrantes (mappé sur 8080 côté hôte) |

#### Entrypoint

Le script `entrypoint.sh` utilise `exec "$@"` :
- `exec` remplace le shell par Nginx (PID 1)
- Nginx gère nativement `SIGQUIT` pour un arrêt graceful
- `STOPSIGNAL SIGQUIT` défini dans le Dockerfile

---

### 4. Portainer (Supervision)

**Fichier** : `tools/portainer/Dockerfile`

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Respecte la contrainte. Portainer est un binaire Go statique. |
| **Téléchargement depuis GitHub Releases** | Portainer est distribué sous forme de binaire précompilé. |
| **Version fixée (2.19.4)** | Reproductibilité des builds. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `wget` | Téléchargement HTTP | Récupère l'archive Portainer depuis GitHub |
| `ca-certificates` | Certificats SSL | Nécessaire pour HTTPS |
| `tzdata` | Fuseaux horaires | Portainer affiche des timestamps |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Téléchargement Portainer** | `wget -q "https://github.com/.../portainer-...-linux-amd64.tar.gz"` | Récupère l'archive officielle |
| **Extraction archive** | `tar -xzf /tmp/portainer.tar.gz -C /opt/` | Extrait dans /opt/portainer/ |
| **Permissions exécution** | `chmod +x /opt/portainer/portainer` | Rend le binaire exécutable |
| **Création répertoire data** | `mkdir -p /data` | Stockage persistant des configurations |
| **Nettoyage** | `rm /tmp/portainer.tar.gz` | Réduit la taille de l'image |

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `--bind-https` | `:9443` | Portainer écoute en HTTPS sur le port 9443 |
| `--data` | `/data` | Répertoire de stockage des données persistantes |

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `9443` | HTTPS | Interface web de gestion Docker |

#### Volumes requis

| Volume | Mode | Pourquoi ? |
|--------|------|------------|
| `/var/run/docker.sock` | RW | Communication avec le daemon Docker |
| `portainer_data:/data` | RW | Persistance des données |

#### Entrypoint

Le script `entrypoint.sh` utilise `exec /opt/portainer/portainer "$@"` :
- Portainer (Go) gère nativement SIGTERM
- Arrêt propre automatique

---

### 5. cAdvisor (Monitoring)

**Fichier** : `tools/cadvisor/Dockerfile`

#### Choix au Build

| Choix | Justification |
|-------|---------------|
| **Image de base `ubuntu:24.04`** | Respecte la contrainte. |
| **Téléchargement depuis GitHub Releases** | Binaire précompilé officiel de Google. |
| **Version fixée (v0.47.2)** | Reproductibilité et stabilité. |

#### Dépendances installées

| Package | Rôle | Pourquoi ? |
|---------|------|------------|
| `wget` | Téléchargement HTTP | Récupère le binaire cAdvisor |
| `ca-certificates` | Certificats SSL | Connexions HTTPS |
| `dmidecode` | Infos matérielles | cAdvisor l'utilise pour les infos hardware |

#### Opérations sur l'OS

| Opération | Commande | Justification |
|-----------|----------|---------------|
| **Téléchargement cAdvisor** | `wget -q "https://github.com/.../cadvisor-..." -O /usr/local/bin/cadvisor` | Télécharge dans le PATH |
| **Permissions exécution** | `chmod +x /usr/local/bin/cadvisor` | Rend le binaire exécutable |
| **Nettoyage cache apt** | `apt-get clean && rm -rf /var/lib/apt/lists/*` | Réduit la taille de l'image |

#### Arguments au Run (CMD)

| Argument | Valeur | Explication |
|----------|--------|-------------|
| `--docker_only=true` | - | Ne surveille que les conteneurs Docker |
| `--disable_metrics=...` | Voir ci-dessous | Désactive les métriques non nécessaires |

**Métriques désactivées :**
- `percpu`, `sched` : Détails CPU avancés non nécessaires
- `tcp`, `udp` : Métriques réseau trop détaillées
- `disk`, `diskIO` : Métriques disque non pertinentes
- `hugetlb`, `referenced_memory` : Détails mémoire avancés
- `cpu_topology`, `resctrl` : Fonctionnalités kernel avancées

#### Port exposé

| Port | Protocole | Usage |
|------|-----------|-------|
| `8080` | HTTP | Interface web (mappé sur 8081 côté hôte) |

#### Volumes requis

| Volume | Mode | Pourquoi ? |
|--------|------|------------|
| `/:/rootfs` | RO | Accès au système de fichiers hôte |
| `/var/run` | RO | Socket Docker |
| `/sys` | RO | Informations cgroups |
| `/var/lib/docker/` | RO | Données des conteneurs |

#### Entrypoint

Le script `entrypoint.sh` utilise `exec /usr/local/bin/cadvisor "$@"` :
- cAdvisor (Go) gère nativement SIGTERM
- Arrêt propre automatique

---

## 🎼 Orchestration Docker Compose

### Variables d'environnement

Les ressources sont configurables via le fichier `.env` ou des variables d'environnement :

| Variable | Défaut | Service | Description |
|----------|--------|---------|-------------|
| `FRONTEND_MEMORY_LIMIT` | `512m` | Frontend | Limite mémoire maximale |
| `FRONTEND_CPU_LIMIT` | `0.5` | Frontend | Limite CPU (0.5 = 50% d'un core) |
| `BACKEND_MEMORY_LIMIT` | `256m` | PHP-FPM | Limite mémoire maximale |
| `BACKEND_CPU_LIMIT` | `0.5` | PHP-FPM | Limite CPU (0.5 = 50% d'un core) |
| `SERVER_MEMORY_LIMIT` | `128m` | Nginx | Limite mémoire maximale |
| `SERVER_CPU_LIMIT` | `0.25` | Nginx | Limite CPU (0.25 = 25% d'un core) |
| `PORTAINER_MEMORY_LIMIT` | `256m` | Portainer | Limite mémoire maximale |
| `PORTAINER_CPU_LIMIT` | `0.25` | Portainer | Limite CPU (0.25 = 25% d'un core) |
| `CADVISOR_MEMORY_LIMIT` | `128m` | cAdvisor | Limite mémoire maximale |
| `CADVISOR_CPU_LIMIT` | `0.25` | cAdvisor | Limite CPU (0.25 = 25% d'un core) |

### Comprendre les limites de ressources

#### Mémoire (`mem_limit`)

La directive `mem_limit` définit la **quantité maximale de RAM** qu'un conteneur peut utiliser :
- `512m` = 512 Mégaoctets
- `1g` = 1 Gigaoctet
- Si le conteneur dépasse cette limite, il est tué par l'OOM Killer (Out Of Memory)

#### CPU (`cpus`)

La directive `cpus` définit la **fraction de CPU** qu'un conteneur peut utiliser :

| Valeur | Signification |
|--------|---------------|
| `0.25` | Le conteneur peut utiliser 25% d'**un** core CPU |
| `0.5` | Le conteneur peut utiliser 50% d'**un** core CPU |
| `1` | Le conteneur peut utiliser **un** core CPU complet |
| `2` | Le conteneur peut utiliser **deux** cores CPU |

**Important** : Ce ne sont **pas des pourcentages du CPU total**, mais des limites **par conteneur**. Sur une machine à 4 cores :
- `cpus: 0.5` = le conteneur peut utiliser au maximum 50% d'un core (soit 12.5% du CPU total)
- Plusieurs conteneurs avec `cpus: 0.5` peuvent coexister sans problème

### Justification des limites de ressources

| Service | Mémoire | CPU | Justification |
|---------|---------|-----|---------------|
| **Frontend** | 512 Mo | 0.5 | http-server est léger, mais Node.js peut consommer de la RAM. 512 Mo est confortable. |
| **PHP-FPM** | 256 Mo | 0.5 | Pool de workers PHP. Chaque worker consomme ~30-50 Mo. 256 Mo permet ~5 workers. |
| **Nginx** | 128 Mo | 0.25 | Nginx est très léger en mémoire. 128 Mo est largement suffisant pour un reverse proxy. |
| **Portainer** | 256 Mo | 0.25 | Interface web Go. Consomme ~100-150 Mo en utilisation normale. |
| **cAdvisor** | 128 Mo | 0.25 | Collecte de métriques. Overhead minimal après optimisation des métriques. |

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

## 🛑 Gestion des Signaux d'Arrêt

Docker envoie des signaux aux conteneurs pour leur demander de s'arrêter. Une gestion correcte assure un **arrêt propre** (graceful shutdown) sans perte de données.

### Comment fonctionne l'arrêt d'un conteneur ?

1. `docker stop` envoie le signal défini par `STOPSIGNAL` (par défaut `SIGTERM`)
2. Le conteneur a **10 secondes** (configurable via `--stop-timeout`) pour s'arrêter
3. Si le conteneur ne s'arrête pas, Docker envoie `SIGKILL` (arrêt forcé)

### Stratégie adoptée : `exec` + `STOPSIGNAL`

Nous utilisons une approche **simple et efficace** :

```dockerfile
# Dans le Dockerfile
STOPSIGNAL SIGQUIT  # ou SIGTERM selon le processus

ENTRYPOINT ["/entrypoint.sh"]
CMD ["processus", "args"]
```

```bash
# Dans entrypoint.sh
#!/bin/bash
exec "$@"  # Remplace le shell par le processus principal
```

**Pourquoi `exec` ?**
- `exec` remplace le processus shell (PID 1) par le processus réel
- Le processus reçoit **directement** les signaux Docker
- Pas besoin de `trap` car le processus gère nativement les signaux

### Signaux par service

| Service | STOPSIGNAL | Comportement |
|---------|------------|--------------|
| **Frontend** | `SIGTERM` | http-server (Node.js) s'arrête immédiatement |
| **PHP-FPM** | `SIGQUIT` | Termine les requêtes PHP en cours, puis s'arrête |
| **Nginx** | `SIGQUIT` | Termine les connexions HTTP en cours, puis s'arrête |
| **Portainer** | `SIGTERM` | Arrêt standard (processus Go) |
| **cAdvisor** | `SIGTERM` | Arrêt standard (processus Go) |

### Différence SIGTERM vs SIGQUIT

| Signal | Comportement | Utilisé par |
|--------|--------------|-------------|
| `SIGTERM` | Arrêt immédiat mais propre | http-server, Portainer, cAdvisor |
| `SIGQUIT` | Arrêt graceful (attend fin des requêtes) | Nginx, PHP-FPM |

### Pourquoi c'est important ?

- **Évite la perte de données** : Les requêtes en cours sont terminées avant l'arrêt
- **Pas de processus zombie** : Le processus se termine correctement
- **Respect du timeout Docker** : Évite le `SIGKILL` forcé après 10 secondes
- **Logs propres** : Les processus écrivent leurs logs de fin correctement

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
