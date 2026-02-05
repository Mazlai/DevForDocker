# 🐳 DevForDocker - Architecture Docker Virtualisée

## 📋 Table des matières
- [Présentation](#-présentation)
- [Architecture](#-architecture) *(→ voir [ARCHITECTURE.md](ARCHITECTURE.md) pour les schémas)*
- [Images Docker](#-images-docker)
  - [Frontend Angular](#1-frontend-angular)
  - [Backend PHP-FPM](#2-backend-php-fpm)
  - [Serveur Web Nginx](#3-serveur-web-nginx)
  - [Portainer](#4-portainer-supervision)
  - [cAdvisor](#5-cadvisor-monitoring)
- [Orchestration Docker Compose](#-orchestration-docker-compose)
- [Gestion des Signaux](#-gestion-des-signaux-darrêt)
- [Démarrage Rapide](#-démarrage-rapide)

*Présenté par Mickael FERNANDEZ*

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

> 📊 **Voir [ARCHITECTURE.md](ARCHITECTURE.md)** pour les schémas détaillés (diagrammes Mermaid, flux de communication, ordre de démarrage, gestion des signaux).

### Vue d'ensemble

| Service | Port exposé | Rôle |
|---------|-------------|------|
| **Frontend** | `4200` | Application Angular (http-server) |
| **Nginx** | `8080` | Reverse proxy vers PHP-FPM |
| **PHP-FPM** | `9000` (interne) | Backend PHP |
| **Portainer** | `9443` (HTTPS) | Interface de gestion Docker |
| **cAdvisor** | `8081` | Monitoring des conteneurs |

### Réseau

Tous les conteneurs sont connectés au réseau `app-network` (bridge), permettant la communication inter-conteneurs via les noms DNS Docker.

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
| **Installation dépendances npm** | `npm ci` | Installe les dépendances exactes depuis `package-lock.json` (plus rapide et reproductible que `npm install`) |
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
- Docker envoie SIGTERM (signal par défaut) directement à `http-server`
- `http-server` (Node.js) gère nativement SIGTERM → pas besoin de définir `STOPSIGNAL`
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
- Portainer est écrit en Go et gère nativement SIGTERM (signal par défaut de Docker)
- `exec` assure que Portainer est PID 1 et reçoit directement les signaux
- Pas besoin de définir `STOPSIGNAL` car SIGTERM est déjà le défaut

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

> **Note** : Ces arguments sont définis dans le Dockerfile (CMD) et également surchargés dans le `docker-compose.yml` via la directive `command:` pour une meilleure visibilité.

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
- cAdvisor est écrit en Go et gère nativement SIGTERM (signal par défaut de Docker)
- `exec` assure que cAdvisor est PID 1 et reçoit directement les signaux
- Pas besoin de définir `STOPSIGNAL` car SIGTERM est déjà le défaut

---

## 🎼 Orchestration Docker Compose

**Fichier** : `docker-compose.yml`

Ce fichier orchestre l'ensemble des services de l'application, définissant comment ils interagissent, leurs ressources, et leurs dépendances.

### Structure du fichier docker-compose.yml

```yaml
services:          # Définition des 5 conteneurs
  frontend:        # Application Angular
  php-fpm:         # Backend PHP
  nginx:           # Serveur web / reverse proxy
  portainer:       # Interface de gestion Docker
  cadvisor:        # Monitoring des conteneurs

networks:          # Réseau interne pour la communication
  app-network:     # Bridge network isolé

volumes:           # Volumes persistants
  portainer_data:  # Données Portainer
```

### Volumes utilisés

#### Volumes Bind Mount (dossiers locaux)

| Volume | Services | Mode | Explication |
|--------|----------|------|-------------|
| `./backend/src:/var/www/html` | php-fpm, nginx | RW | Partage le code PHP entre l'hôte et les conteneurs. Permet de modifier le code sans reconstruire l'image. Nginx sert les fichiers, PHP-FPM les exécute. |
| `/var/run/docker.sock:/var/run/docker.sock` | portainer | RW | Socket Docker permettant à Portainer de communiquer avec le daemon Docker pour gérer les conteneurs, images, volumes. |
| `/:/rootfs` | cadvisor | RO | Accès au système de fichiers racine de l'hôte pour collecter les métriques système. |
| `/var/run:/var/run` | cadvisor | RO | Accès aux sockets et PIDs des processus en cours. |
| `/sys:/sys` | cadvisor | RO | Accès aux informations du noyau Linux (CPU, mémoire, cgroups). |
| `/var/lib/docker/:/var/lib/docker/` | cadvisor | RO | Accès aux données Docker pour les métriques de stockage des conteneurs. |

> **Note** : Le flag `:ro` signifie **lecture seule** (read-only) - cAdvisor ne peut pas modifier ces fichiers.

#### Volumes Nommés (persistance Docker)

| Volume | Service | Chemin interne | Explication |
|--------|---------|----------------|-------------|
| `portainer_data` | portainer | `/data` | Stocke la base de données Portainer (utilisateurs, configurations, paramètres). Persiste même si le conteneur est supprimé. Géré par Docker dans `/var/lib/docker/volumes/`. |

### Réseau Docker

```yaml
networks:
  app-network:
    driver: bridge
```

| Propriété | Valeur | Explication |
|-----------|--------|-------------|
| **Nom** | `app-network` | Réseau Docker isolé pour l'application |
| **Driver** | `bridge` | Mode bridge : les conteneurs peuvent communiquer entre eux via leurs noms DNS |
| **Isolation** | Oui | Les conteneurs de ce réseau sont isolés des autres réseaux Docker |

**Communication inter-services** : Grâce au réseau bridge, Nginx peut atteindre PHP-FPM via `php-fpm:9000` (nom DNS Docker automatique).

### Variables d'environnement

Les ressources sont configurables via le fichier `.env`. Le projet utilise la syntaxe moderne `deploy.resources` avec **limits** (maximum) et **reservations** (minimum garanti) :

#### Variables de Limits (Maximum autorisé)

| Variable | Défaut | Service | Description |
|----------|--------|---------|-------------|
| `FRONTEND_MEMORY_LIMIT` | `512m` | Frontend | Mémoire maximale autorisée |
| `FRONTEND_CPU_LIMIT` | `0.5` | Frontend | CPU maximum (0.5 = 50% d'un core) |
| `BACKEND_MEMORY_LIMIT` | `256m` | PHP-FPM | Mémoire maximale autorisée |
| `BACKEND_CPU_LIMIT` | `0.5` | PHP-FPM | CPU maximum |
| `SERVER_MEMORY_LIMIT` | `128m` | Nginx | Mémoire maximale autorisée |
| `SERVER_CPU_LIMIT` | `0.25` | Nginx | CPU maximum |
| `PORTAINER_MEMORY_LIMIT` | `256m` | Portainer | Mémoire maximale autorisée |
| `PORTAINER_CPU_LIMIT` | `0.25` | Portainer | CPU maximum |
| `CADVISOR_MEMORY_LIMIT` | `128m` | cAdvisor | Mémoire maximale autorisée |
| `CADVISOR_CPU_LIMIT` | `0.25` | cAdvisor | CPU maximum |

#### Variables de Reservations (Minimum garanti)

| Variable | Défaut | Service | Description |
|----------|--------|---------|-------------|
| `FRONTEND_MEMORY_RESERVATION` | `128m` | Frontend | Mémoire garantie réservée |
| `FRONTEND_CPU_RESERVATION` | `0.1` | Frontend | CPU garanti |
| `BACKEND_MEMORY_RESERVATION` | `64m` | PHP-FPM | Mémoire garantie (1 worker) |
| `BACKEND_CPU_RESERVATION` | `0.1` | PHP-FPM | CPU garanti |
| `SERVER_MEMORY_RESERVATION` | `32m` | Nginx | Mémoire garantie |
| `SERVER_CPU_RESERVATION` | `0.05` | Nginx | CPU garanti |
| `PORTAINER_MEMORY_RESERVATION` | `64m` | Portainer | Mémoire garantie |
| `PORTAINER_CPU_RESERVATION` | `0.05` | Portainer | CPU garanti |
| `CADVISOR_MEMORY_RESERVATION` | `32m` | cAdvisor | Mémoire garantie |
| `CADVISOR_CPU_RESERVATION` | `0.05` | cAdvisor | CPU garanti |

### Comprendre les limites de ressources

Le projet utilise la syntaxe moderne `deploy.resources` avec deux niveaux de contrôle :

```yaml
deploy:
  resources:
    limits:        # Maximum autorisé (plafond)
      memory: 512M
      cpus: '0.5'
    reservations:  # Minimum garanti (plancher)
      memory: 128M
      cpus: '0.1'
```

#### Limits vs Reservations

| Concept | Rôle | Comportement |
|---------|------|--------------|
| **limits** | Plafond maximum | Le conteneur est tué si dépassé (OOM Killer) |
| **reservations** | Plancher garanti | Ressources réservées même sous pression système |

#### Pourquoi utiliser les deux ?

| Avantage | Explication |
|----------|-------------|
| **Garantie de démarrage** | Les reservations assurent que le conteneur démarre toujours avec ses ressources minimales |
| **Stabilité sous charge** | Même si l'hôte est saturé, les ressources réservées sont protégées |
| **Scheduling intelligent** | Docker place les conteneurs sur des nœuds avec assez de ressources disponibles |
| **Protection de l'hôte** | Les limits empêchent un conteneur de monopoliser toutes les ressources |

#### Mémoire

| Concept | Format | Exemple | Comportement |
|---------|--------|---------|--------------|
| **limits.memory** | `512m`, `1g` | `memory: 512m` | Le conteneur est tué par l'OOM Killer si dépassé |
| **reservations.memory** | `128m`, `256m` | `memory: 128m` | Cette quantité est réservée et garantie |

#### CPU

| Valeur | Signification |
|--------|---------------|
| `0.05` | 5% d'**un** core CPU |
| `0.1` | 10% d'**un** core CPU |
| `0.25` | 25% d'**un** core CPU |
| `0.5` | 50% d'**un** core CPU |
| `1` | **Un** core CPU complet |

**Important** : Ce ne sont **pas des pourcentages du CPU total**, mais des limites **par conteneur**. Sur une machine à 4 cores :
- `limits.cpus: 0.5` = le conteneur peut utiliser au maximum 50% d'un core
- `reservations.cpus: 0.1` = 10% d'un core est garanti pour ce conteneur

### Justification des limites de ressources

Les limites de ressources ont été définies en fonction du **profil de consommation réel** de chaque service et de **bonnes pratiques de production**.

#### Frontend (Angular) — 512 Mo / 0.5 CPU

| Aspect | Valeur | Justification détaillée |
|--------|--------|-------------------------|
| **Mémoire** | 512 Mo | `http-server` est un serveur HTTP Node.js léger (~50-80 Mo en idle). Cependant, Node.js alloue un heap par défaut pouvant atteindre ~512 Mo. Cette limite permet de gérer des pics de connexions simultanées sans risque d'OOM. |
| **CPU** | 0.5 | Servir des fichiers statiques (HTML, JS, CSS) est une opération I/O-bound, pas CPU-intensive. 0.5 CPU est largement suffisant même pour plusieurs centaines de requêtes/seconde. |

**Pourquoi pas moins de mémoire ?**  
Node.js a un garbage collector qui fonctionne mieux avec de la marge. Réduire à 128 Mo causerait des GC fréquents et des latences.

#### Backend PHP-FPM — 256 Mo / 0.5 CPU

| Aspect | Valeur | Justification détaillée |
|--------|--------|-------------------------|
| **Mémoire** | 256 Mo | PHP-FPM utilise un modèle **worker pool**. Chaque worker consomme ~30-50 Mo selon le code PHP. Avec 256 Mo, on peut avoir ~5 workers simultanés (config par défaut : `pm.max_children = 5`). |
| **CPU** | 0.5 | PHP est single-threaded par requête. 0.5 CPU permet de traiter plusieurs requêtes en parallèle via les workers, sans monopoliser les ressources. |

**Calcul de la mémoire :**
```
Mémoire totale = (workers × mémoire/worker) + overhead FPM
256 Mo = (5 × 40 Mo) + 56 Mo overhead
```

**Pourquoi pas plus de CPU ?**  
PHP-FPM est généralement I/O-bound (attente BDD, fichiers). Augmenter le CPU n'améliorerait pas les performances pour notre cas d'usage simple.

#### Nginx — 128 Mo / 0.25 CPU

| Aspect | Valeur | Justification détaillée |
|--------|--------|-------------------------|
| **Mémoire** | 128 Mo | Nginx est **extrêmement léger** (~10-20 Mo en idle). Il utilise une architecture événementielle (event-driven) avec un seul thread par worker. 128 Mo est généreux et permet de gérer des milliers de connexions simultanées. |
| **CPU** | 0.25 | En tant que reverse proxy, Nginx fait du **pass-through** vers PHP-FPM. L'overhead CPU est minimal (parsing HTTP, forwarding). 0.25 CPU suffit pour notre charge. |

**Pourquoi Nginx est si léger ?**  
Contrairement à Apache (modèle thread/process par connexion), Nginx utilise `epoll` (Linux) pour gérer des milliers de connexions dans un seul thread avec très peu de RAM.

#### Portainer — 256 Mo / 0.25 CPU

| Aspect | Valeur | Justification détaillée |
|--------|--------|-------------------------|
| **Mémoire** | 256 Mo | Portainer est une application **Go** avec interface web React. En idle, il consomme ~100-150 Mo. 256 Mo permet d'afficher de nombreux conteneurs/logs sans problème. |
| **CPU** | 0.25 | L'interface est rafraîchie toutes les quelques secondes. Les appels à l'API Docker sont légers. 0.25 CPU est suffisant pour un usage normal. |

**Pourquoi Go consomme plus que Nginx ?**  
Portainer embarque une BDD (BoltDB), un serveur web, et doit maintenir l'état des connexions WebSocket pour les logs en temps réel.

#### cAdvisor — 128 Mo / 0.25 CPU

| Aspect | Valeur | Justification détaillée |
|--------|--------|-------------------------|
| **Mémoire** | 128 Mo | cAdvisor collecte des métriques système toutes les secondes. Avec les métriques désactivées (`--disable_metrics`), il consomme ~50-80 Mo. 128 Mo offre une marge de sécurité. |
| **CPU** | 0.25 | La collecte de métriques lit principalement `/proc` et `/sys` (I/O). Le calcul des statistiques est léger. 0.25 CPU est adapté. |

**Impact de `--disable_metrics` :**
```
Sans optimisation : ~200 Mo RAM, ~0.5 CPU
Avec --disable_metrics : ~80 Mo RAM, ~0.1 CPU (économie de 60%)
```

#### Récapitulatif et total des ressources

| Service | Limite Mémoire | Réservation Mémoire | Limite CPU | Réservation CPU | Type de charge |
|---------|----------------|---------------------|------------|-----------------|----------------|
| Frontend | 512 Mo | 128 Mo | 0.5 | 0.1 | I/O-bound (fichiers statiques) |
| PHP-FPM | 256 Mo | 64 Mo | 0.5 | 0.1 | I/O-bound (requêtes BDD, fichiers) |
| Nginx | 128 Mo | 32 Mo | 0.25 | 0.05 | I/O-bound (proxy HTTP) |
| Portainer | 256 Mo | 64 Mo | 0.25 | 0.05 | Mixte (UI + API Docker) |
| cAdvisor | 128 Mo | 32 Mo | 0.25 | 0.05 | I/O-bound (lecture /proc, /sys) |
| **TOTAL Limits** | **1.28 Go** | — | **1.75 CPU** | — | — |
| **TOTAL Reservations** | — | **320 Mo** | — | **0.35 CPU** | — |

> **Note** : 
> - **Limits** = Maximum autorisé (le conteneur ne peut pas dépasser)
> - **Reservations** = Minimum garanti (ressources réservées même sous pression)
> - En utilisation normale, les conteneurs consomment entre les reservations et les limits

### Ordre de démarrage (depends_on)

> 📊 **Voir le diagramme dans [ARCHITECTURE.md](ARCHITECTURE.md#ordre-de-démarrage)**

| Phase | Service | Condition | Attend |
|-------|---------|-----------|--------|
| 1 | **php-fpm** | - | Démarre en premier |
| 2 | **nginx** | `service_healthy` | PHP-FPM healthy |
| 3 | **portainer** | `service_healthy` | Nginx healthy |
| 4 | **cadvisor** | `service_started` | Portainer démarré |
| - | **frontend** | - | Indépendant |

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

> 📊 **Voir les diagrammes dans [ARCHITECTURE.md](ARCHITECTURE.md#gestion-des-signaux)**

Docker envoie des signaux aux conteneurs pour leur demander de s'arrêter. Une gestion correcte assure un **arrêt propre** (graceful shutdown) sans perte de données.

### Comment fonctionne l'arrêt d'un conteneur ?

1. `docker stop` envoie le signal défini par `STOPSIGNAL` (par défaut `SIGTERM`)
2. Le conteneur a **10 secondes** (configurable via `--stop-timeout`) pour s'arrêter
3. Si le conteneur ne s'arrête pas, Docker envoie `SIGKILL` (arrêt forcé)

### Stratégie adoptée : `exec` dans l'entrypoint

```bash
# Dans entrypoint.sh
#!/bin/bash
exec "$@"  # Remplace le shell par le processus principal
```

**Pourquoi `exec` ?**
- `exec` remplace le processus shell (PID 1) par le processus réel
- Le processus reçoit **directement** les signaux Docker
- Pas besoin de `trap` car le processus gère nativement les signaux

### STOPSIGNAL : quand le définir ?

**SIGTERM est le signal par défaut** envoyé par Docker. Il n'est donc **pas nécessaire** de le spécifier dans le Dockerfile si le processus le gère nativement.

On définit explicitement `STOPSIGNAL` uniquement quand on veut un signal **différent** du défaut :

```dockerfile
# Uniquement pour PHP-FPM et Nginx qui préfèrent SIGQUIT
STOPSIGNAL SIGQUIT
```

### Signaux par service

| Service | Signal reçu | Défini explicitement ? | Comportement |
|---------|-------------|------------------------|---------------|
| **Frontend** | `SIGTERM` | Non (défaut Docker) | Node.js s'arrête proprement |
| **PHP-FPM** | `SIGQUIT` | ✅ Oui | Arrêt graceful (termine les requêtes en cours) |
| **Nginx** | `SIGQUIT` | ✅ Oui | Arrêt graceful (termine les connexions actives) |
| **Portainer** | `SIGTERM` | Non (défaut Docker) | Go s'arrête proprement |
| **cAdvisor** | `SIGTERM` | Non (défaut Docker) | Go s'arrête proprement |

**Pourquoi SIGQUIT pour PHP-FPM et Nginx ?**
- `SIGTERM` : Arrêt rapide (peut couper des requêtes/connexions en cours)
- `SIGQUIT` : Arrêt graceful (attend la fin des traitements avant de s'arrêter)

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
```

> **Note** : Les limites de ressources sont configurées dans le fichier `.env`. Modifiez-le directement pour ajuster les valeurs (mémoire, CPU) sans toucher au `docker-compose.yml`.

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
