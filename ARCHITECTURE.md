# 📊 Schéma d'Architecture - DevForDocker

Ce document présente les **schémas visuels** d'architecture du projet au format Mermaid (compatible GitHub, GitLab, etc.).

> 📖 **Pour la documentation complète** (explications détaillées, dépendances, arguments, justifications), voir [README.md](README.md).

*Présenté par Mickael FERNANDEZ*

---

## Choix d'Architecture

### Pourquoi cette stack ?

| Composant | Choix | Alternatives possibles | Justification |
|-----------|-------|----------------------|---------------|
| **Frontend** | Angular + http-server | React, Vue, nginx | Angular CLI pour le build, http-server léger pour servir |
| **Backend** | PHP-FPM | Node.js, Python | PHP reste très répandu, FPM est performant |
| **Serveur Web** | Nginx | Apache, Caddy | Nginx excelle en reverse proxy et performance |
| **Supervision** | Portainer | Rancher, Kubernetes Dashboard | Léger et adapté pour Docker standalone |
| **Monitoring** | cAdvisor | Prometheus seul, Grafana | Métriques Docker natives, interface web incluse |

### Comparaison Ubuntu vs Alpine

La question du choix de l'image de base est cruciale en production. Voici une comparaison détaillée :

| Critère | Ubuntu 24.04 | Alpine Linux |
|---------|--------------|--------------|
| **Taille de base** | ~78 Mo | ~5 Mo |
| **Gestionnaire de paquets** | apt (dpkg) | apk |
| **Bibliothèque C** | glibc | musl libc |
| **Shell par défaut** | bash | ash (BusyBox) |
| **Support LTS** | 5 ans (→ 2029) | ~2 ans par version |
| **Communauté** | Très large | En croissance |

#### Avantages d'Ubuntu (notre choix)

| Avantage | Explication |
|----------|-------------|
| **Compatibilité maximale** | glibc est la bibliothèque C standard, tous les binaires précompilés fonctionnent sans problème |
| **Debugging facilité** | Outils de diagnostic complets (`strace`, `ltrace`, etc.) disponibles |
| **Documentation abondante** | Très bien documenté, nombreuses ressources en ligne |
| **Packages récents** | Ubuntu 24.04 inclut PHP 8.3, Nginx 1.24+ nativement |
| **Stabilité éprouvée** | LTS avec 5 ans de support et mises à jour de sécurité |

#### Avantages d'Alpine (alternative)

| Avantage | Explication |
|----------|-------------|
| **Taille d'image réduite** | ~5 Mo vs ~78 Mo pour Ubuntu, gain significatif en stockage et transfert |
| **Surface d'attaque minimale** | Moins de packages installés = moins de vulnérabilités potentielles |
| **Démarrage plus rapide** | Image plus petite = pull et démarrage plus rapides |
| **Optimisé pour les conteneurs** | Conçu dès le départ pour Docker et les microservices |

#### Inconvénients d'Alpine (pourquoi on ne l'utilise pas ici)

| Inconvénient | Impact |
|--------------|--------|
| **musl libc vs glibc** | Certains binaires précompilés (comme Portainer, cAdvisor) peuvent avoir des problèmes de compatibilité |
| **Packages moins nombreux** | Certains packages doivent être compilés manuellement |
| **Debugging plus difficile** | Outils de base limités (BusyBox), moins de verbosité par défaut |
| **Problèmes DNS potentiels** | musl gère DNS différemment, peut causer des problèmes avec certaines applications |
| **Performances variables** | musl peut être plus lent que glibc pour certaines opérations (allocation mémoire, threads) |

#### Comparaison des tailles d'images (estimées)

| Image | Avec Ubuntu 24.04 | Avec Alpine | Économie |
|-------|-------------------|-------------|----------|
| Frontend (Node.js) | ~450 Mo | ~150 Mo | ~67% |
| Backend (PHP-FPM) | ~250 Mo | ~80 Mo | ~68% |
| Nginx | ~180 Mo | ~25 Mo | ~86% |
| Portainer | ~280 Mo | ⚠️ Binaire glibc | N/A |
| cAdvisor | ~200 Mo | ⚠️ Binaire glibc | N/A |

> **Note** : Portainer et cAdvisor sont distribués en binaires compilés pour glibc. Les faire fonctionner sur Alpine nécessiterait d'installer `gcompat` (couche de compatibilité glibc) ou de recompiler depuis les sources.

#### Quand choisir Alpine ?

- ✅ Microservices légers avec peu de dépendances
- ✅ Applications Node.js ou Go pures (bien supportées sur musl)
- ✅ Environnements avec bande passante limitée (réduction du temps de pull)
- ✅ Besoin de réduire la surface d'attaque (sécurité)

#### Quand choisir Ubuntu ?

- ✅ Applications avec binaires précompilés (Portainer, cAdvisor)
- ✅ Stack PHP (meilleur support des extensions)
- ✅ Besoin d'outils de debugging avancés
- ✅ Équipe familière avec l'écosystème Debian/Ubuntu
- ✅ Support long terme et stabilité prioritaires

**Notre choix : Ubuntu 24.04** pour sa compatibilité universelle avec tous nos composants (binaires glibc de Portainer/cAdvisor) et le respect de la contrainte du projet (images construites depuis zéro).

---

## Architecture Globale

```mermaid
flowchart TB
    subgraph Internet["🌐 Internet / Client"]
        Client[("👤 Utilisateur")]
    end

    subgraph Host["🖥️ Hôte Docker"]
        subgraph Network["📡 Réseau: app-network (bridge)"]
            
            subgraph Frontend["Frontend"]
                FE["🅰️ Angular<br/>Port: 4200<br/>http-server"]
            end
            
            subgraph Backend["Backend Stack"]
                NGINX["🌐 Nginx<br/>Port: 8080→80<br/>Reverse Proxy"]
                PHP["🐘 PHP-FPM<br/>Port: 9000<br/>FastCGI"]
            end
            
            subgraph Monitoring["Outils de Supervision"]
                PORT["🔧 Portainer<br/>Port: 9443<br/>HTTPS"]
                CAD["📈 cAdvisor<br/>Port: 8081<br/>Métriques"]
            end
        end
        
        subgraph Volumes["💾 Volumes"]
            VOL1[("portainer_data")]
            VOL2[("./backend/src")]
        end
        
        SOCK["/var/run/docker.sock"]
    end

    Client -->|":4200"| FE
    Client -->|":8080"| NGINX
    Client -->|":9443"| PORT
    Client -->|":8081"| CAD
    
    NGINX -->|"FastCGI :9000"| PHP
    
    PHP -.->|"mount"| VOL2
    NGINX -.->|"mount"| VOL2
    
    PORT -.->|"mount"| VOL1
    PORT -.->|"socket"| SOCK
    CAD -.->|"socket"| SOCK
```

## Flux de Requêtes HTTP

```mermaid
sequenceDiagram
    participant C as 👤 Client
    participant N as 🌐 Nginx
    participant P as 🐘 PHP-FPM
    participant F as 📁 Fichiers

    C->>N: GET /index.php (port 8080)
    N->>N: Route vers PHP
    N->>P: FastCGI (port 9000)
    P->>F: Lecture /var/www/html/index.php
    F-->>P: Contenu PHP
    P->>P: Exécution PHP
    P-->>N: Réponse HTML
    N-->>C: HTTP 200 + HTML
```

## Ordre de Démarrage

```mermaid
flowchart TD
    subgraph Phase1["Phase 1 - Backend"]
        PHP["🐘 PHP-FPM<br/>⏳ Démarre"]
    end
    
    subgraph Phase2["Phase 2 - Serveur Web"]
        NGINX["🌐 Nginx<br/>⏳ Attend PHP healthy"]
    end
    
    subgraph Phase3["Phase 3 - Supervision"]
        PORT["🔧 Portainer<br/>⏳ Attend Nginx healthy"]
    end
    
    subgraph Phase4["Phase 4 - Monitoring"]
        CAD["📈 cAdvisor<br/>⏳ Attend Portainer started"]
    end
    
    subgraph Independent["Indépendant"]
        FE["🅰️ Frontend<br/>✅ Aucune dépendance"]
    end
    
    PHP -->|"service_healthy"| NGINX
    NGINX -->|"service_healthy"| PORT
    PORT -->|"service_started"| CAD
```

## Gestion des Signaux

> 📖 **Explications détaillées** : voir [README.md - Gestion des Signaux](README.md#-gestion-des-signaux-darrêt)

```mermaid
flowchart LR
    subgraph Docker["Docker Engine"]
        STOP["docker stop"]
    end
    
    subgraph Container["Conteneur"]
        EP["entrypoint.sh<br/>exec $@"]
        PROC["Processus Principal<br/>(PID 1)"]
    end
    
    STOP -->|"Signal<br/>(défaut: SIGTERM)"| EP
    EP -->|"exec remplace<br/>le shell"| PROC
    PROC -->|"Gestion native<br/>du signal"| EXIT["Arrêt propre"]
```

### Stratégie par Service

```mermaid
flowchart TB
    subgraph Frontend["Frontend (http-server)"]
        F1["Signal: SIGTERM (défaut)"]
        F2["Node.js gère nativement"]
        F3["Arrêt propre"]
        F1 --> F2 --> F3
    end
    
    subgraph Backend["Backend (PHP-FPM)"]
        B1["STOPSIGNAL: SIGQUIT ✅"]
        B2["PHP-FPM termine<br/>les requêtes en cours"]
        B3["Arrêt graceful"]
        B1 --> B2 --> B3
    end
    
    subgraph Web["Serveur Web (Nginx)"]
        W1["STOPSIGNAL: SIGQUIT ✅"]
        W2["Nginx termine<br/>les connexions actives"]
        W3["Arrêt graceful"]
        W1 --> W2 --> W3
    end
```

## Ressources Allouées

> 📖 **Justifications détaillées** : voir [README.md - Justification des limites](README.md#justification-des-limites-de-ressources)

### Limites Mémoire

```mermaid
pie title Limites Mémoire par Conteneur
    "Frontend (512 Mo)" : 512
    "PHP-FPM (256 Mo)" : 256
    "Portainer (256 Mo)" : 256
    "Nginx (128 Mo)" : 128
    "cAdvisor (128 Mo)" : 128
```

### Limites CPU

```mermaid
flowchart LR
    subgraph Limites["Limites CPU par conteneur"]
        FE["Frontend<br/>0.5 core"]
        PHP["PHP-FPM<br/>0.5 core"]
        NG["Nginx<br/>0.25 core"]
        PO["Portainer<br/>0.25 core"]
        CA["cAdvisor<br/>0.25 core"]
    end
```

## Communication Inter-Services

```mermaid
flowchart LR
    subgraph Externe["Ports Externes (Hôte)"]
        E1["4200"]
        E2["8080"]
        E3["9443"]
        E4["8081"]
    end
    
    subgraph Interne["Réseau Docker Interne"]
        FE["Frontend:4200"]
        NG["Nginx:80"]
        PH["PHP-FPM:9000"]
        PO["Portainer:9443"]
        CA["cAdvisor:8080"]
    end
    
    E1 <--> FE
    E2 <--> NG
    E3 <--> PO
    E4 <--> CA
    
    NG <-->|"FastCGI"| PH
```

---

## Visualisation

Pour visualiser ces schémas :

1. **GitHub/GitLab** : Les diagrammes Mermaid sont rendus automatiquement
2. **VS Code** : Installer l'extension "Markdown Preview Mermaid Support"
3. **En ligne** : Utiliser [Mermaid Live Editor](https://mermaid.live/)

---

## Voir aussi

- **[README.md](README.md)** : Documentation principale complète (images, dépendances, arguments, justifications des ressources, démarrage rapide)

---

*Schémas générés pour le projet DevForDocker - Février 2026*
