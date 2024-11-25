# Introduction

Ce projet a pour objectif de mettre en place une infrastructure Docker pour héberger une application 3-tiers et un tableau de bord centralisé. Nous avons déployé un système composé des services suivants :

- **GLPI** : Une application de gestion de parc informatique.
- **MariaDB** : La base de données pour stocker les informations de GLPI.
- **Uptime Kuma** : Un outil de monitoring pour surveiller l'état des services.
- **Frontend (Apache)** : Un tableau de bord centralisé pour accéder facilement aux services.

L'architecture repose sur Docker Compose, avec des conteneurs interagissant dans un environnement réseau dédié pour garantir l'isolation et la sécurité des services. Un script de sauvegarde automatisé a également été mis en place pour garantir la pérennité des données et des healthchecks.


---

# Architecture du Projet

## Description générale

Le projet repose sur une architecture modulaire et bien isolée :

- **Encapsulation des services** : Chaque service est encapsulé dans un conteneur Docker.
- **Tableau de bord centralisé** : Un frontend permet d'accéder facilement aux différents services.
- **Réseaux spécifiques** : Des réseaux dédiés gèrent les communications entre les services tout en limitant les interactions indésirables.
- **Persistance des données** : Les volumes Docker garantissent la sauvegarde et la persistance des données critiques.


---

## Structure Réseau

Pour garantir une isolation adéquate, les réseaux suivants ont été créés :

- **frontend-network** : Permet aux utilisateurs d'accéder à GLPI, Uptime Kuma, et au tableau de bord centralisé.
- **bdd-network** : Relie GLPI et MariaDB de manière sécurisée, empêchant tout accès externe à la base de données.
- **backend-network** : Permet les communications internes pour le monitoring de Uptime Kuma.


---

## Schéma de Connectivité

| **Source**      | **Destination** | **Ping possible ?** |
|------------------|-----------------|----------------------|
| **GLPI**         | **MariaDB**     | ✅ Oui              |
| **GLPI**         | **Uptime Kuma** | ✅ Oui              |
| **MariaDB**      | **GLPI**        | ✅ Oui              |
| **MariaDB**      | **Uptime Kuma** | ❌ Non              |
| **Uptime Kuma**  | **GLPI**        | ✅ Oui (HTTP)       |
| **Uptime Kuma**  | **MariaDB**     | ❌ Non              |
| **Frontend**     | **GLPI**        | ✅ Oui              |
| **Frontend**     | **Uptime Kuma** | ✅ Oui              |

---

# 1. Structure du Projet

## Arborescence

Le projet est structuré pour séparer les configurations, les scripts, et les sauvegardes. Voici l'organisation des fichiers et dossiers principaux :

- **`docker-compose.yaml`** : Orchestre les conteneurs et définit les réseaux, volumes, et services.
- **`glpi/`** : Contient les fichiers nécessaires pour construire l'image Docker de GLPI.
- **`backup/`** : Regroupe les scripts pour les sauvegardes automatisées.
- **`docker-backups/`** : Stocke les données archivées et les snapshots de sauvegarde.

Cette structure facilite la maintenance et l'évolutivité du projet.

```
├── docker-compose.yaml
├── glpi/
│   └── Dockerfile
├── apache-html/
│   └── index.html
├── backup/
│   └── backup_volumes.sh
└── docker-backups/

```

# 2. Image Docker GLPI

Le conteneur GLPI est construit à partir d’un Dockerfile personnalisé. Ce fichier intègre les dépendances nécessaires, télécharge la dernière version stable de GLPI et configure les permissions :

```dockerfile
# Base image
FROM php:8.1-apache

# Mettre à jour le système et installer les dépendances nécessaires pour GLPI
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    zlib1g-dev \
    libzip-dev \
    libicu-dev \
    libbz2-dev \
    libldap2-dev \
    unzip \
    wget \
    iputils-ping \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && docker-php-ext-install mysqli zip intl bz2 ldap exif opcache

# Télécharger GLPI
RUN wget https://github.com/glpi-project/glpi/releases/download/10.0.17/glpi-10.0.17.tgz \
    && tar -xzf glpi-10.0.17.tgz -C /var/www/html \
    && rm glpi-10.0.17.tgz

# Configurer les permissions
RUN chown -R www-data:www-data /var/www/html/glpi && chmod -R 775 /var/www/html/glpi

# Exposer le port Apache
EXPOSE 80

# Commande par défaut
CMD ["apache2-foreground"]
```
# 3. Healthcheck

Des **healthchecks** ont été ajoutés pour chaque conteneur afin de surveiller leur état. Ces tests permettent de valider automatiquement le bon fonctionnement des services :

- **GLPI** : Vérifie que le service est accessible via HTTP.
- **MariaDB** : Vérifie que le service de base de données répond aux commandes.
- **Uptime Kuma** : Vérifie l'accès au tableau de bord via HTTP.

Voici un exemple de configuration de healthcheck pour vérifier l'accès au tableau de bord d'Uptime Kuma :
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://192.168.0.157:3001/dashboard"]
  interval: 30s
  timeout: 10s
  retries: 3
```
### Détails de la configuration :

- **test** : Commande exécutée pour vérifier si le service est fonctionnel (dans cet exemple, une requête HTTP via `curl`).
- **interval** : Intervalle entre deux exécutions du healthcheck (30 secondes).
- **timeout** : Délai maximum avant qu'une tentative ne soit considérée comme échouée (10 secondes).
- **retries** : Nombre de tentatives avant de considérer le service comme défaillant (3 fois).

# 4. Script de Sauvegarde

Un script de sauvegarde automatisé a été créé pour préserver les données critiques des volumes Docker. Il archive chaque volume dans un dossier dédié.

---

## Contenu du script

```bash
#!/bin/bash

BACKUP_DIR="/home/ryan/TP/docker-backups"
DATE=$(date +'%Y-%m-%d')

VOLUMES=("tp_db-data" "tp_uptime-kuma-data" "glpi-data")

mkdir -p "$BACKUP_DIR"

for VOLUME in "${VOLUMES[@]}"; do
    echo "Sauvegarde du volume $VOLUME..."
    docker run --rm \
        -v ${VOLUME}:/volume \
        -v ${BACKUP_DIR}:/backup \
        alpine \
```
## Fonctionnement du Script

Ce script sauvegarde les 3 volumes associés aux 3 conteneurs suivants :

- **GLPI** : Volume `glpi-data`
- **MariaDB** : Volume `tp_db-data`
- **Uptime Kuma** : Volume `tp_uptime-kuma-data`

Les sauvegardes sont stockées dans le dossier suivant :  
`/home/ryan/TP/docker-backups`.

### Automatisation avec Cron

Pour automatiser cette tâche, une ligne de commande Cron a été ajoutée. Elle exécute le script tous les jours à 3h du matin :

```bash
0 3 * * * /bin/bash /home/ryan/TP/Backup/backup_volumes.sh
```

# Docker Compose Configuration

Voici la configuration `docker-compose.yaml` utilisée pour orchestrer les conteneurs et gérer les services dans un environnement 3-tiers. 
```
version: "3.8"
services:
  glpi:
    build:
      context: ./glpi
    container_name: tp-glpi-1
    ports:
      - "8080:80"
    volumes:
      - glpi-data:/var/www/html
    networks:
      - frontend-network
      - bdd-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://192.168.0.157:8080/glpi"]
      interval: 30s
      timeout: 10s
      retries: 3

  mariadb:
    image: mariadb:10.6
    container_name: tp-mariadb-1
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: glpidb
      MYSQL_USER: glpiuser
      MYSQL_PASSWORD: glpipassword
    volumes:
      - db-data:/var/lib/mysql
    networks:
      - bdd-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-u", "root", "--password=rootpassword"]
      interval: 30s
      timeout: 10s
      retries: 3

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: tp-uptime-kuma-1
    ports:
      - "3001:3001"
    volumes:
      - uptime-kuma-data:/app/data
    networks:
      - backend-network
      - frontend-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://192.168.0.157:3001/dashboard"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  frontend-network:
  backend-network:
  bdd-network:

volumes:
  db-data:
  uptime-kuma-data:
  glpi-data:
```

## Services Configurés

### 1. **GLPI**
- **Build** : Construit à partir d'un Dockerfile personnalisé situé dans le dossier `./glpi`.
- **Conteneur** : `tp-glpi-1`
- **Ports** : Redirige le port `80` du conteneur vers le port `8080` de l'hôte.
- **Volumes** : 
  - Utilise le volume `glpi-data` pour stocker les fichiers persistants dans `/var/www/html`.
- **Réseaux** :
  - Connecté au réseau public `frontend-network`.
  - Connecté au réseau interne `bdd-network` pour communiquer avec MariaDB.
- **Healthcheck** :
  - Vérifie que l'interface web de GLPI est accessible via HTTP à l'adresse `http://192.168.0.157:8080/glpi`.

---

### 2. **MariaDB**
- **Image** : `mariadb:10.6`
- **Conteneur** : `tp-mariadb-1`
- **Ports** : Redirige le port `3306` du conteneur vers le port `3306` de l'hôte.
- **Variables d'environnement** :
  - `MYSQL_ROOT_PASSWORD` : Mot de passe root.
  - `MYSQL_DATABASE` : Base de données utilisée par GLPI.
  - `MYSQL_USER` et `MYSQL_PASSWORD` : Identifiants de l'utilisateur GLPI.
- **Volumes** : 
  - Utilise le volume `db-data` pour stocker les données de la base dans `/var/lib/mysql`.
- **Réseaux** :
  - Connecté uniquement au réseau interne `bdd-network` pour la sécurité.
- **Healthcheck** :
  - Vérifie que le service MySQL répond aux commandes en ligne via `mysqladmin`.

---

### 3. **Uptime Kuma**
- **Image** : `louislam/uptime-kuma:latest`
- **Conteneur** : `tp-uptime-kuma-1`
- **Ports** : Redirige le port `3001` du conteneur vers le port `3001` de l'hôte.
- **Volumes** :
  - Utilise le volume `uptime-kuma-data` pour stocker les configurations dans `/app/data`.
- **Réseaux** :
  - Connecté au réseau public `frontend-network`.
  - Connecté au réseau interne `backend-network` pour le monitoring.
- **Healthcheck** :
  - Vérifie l'accès au tableau de bord via HTTP à l'adresse `http://192.168.0.157:3001/dashboard`.

---

## Volumes

Des volumes sont utilisés pour assurer la persistance des données :
- **`db-data`** : Stocke les données de MariaDB.
- **`uptime-kuma-data`** : Stocke les configurations et logs d'Uptime Kuma.
- **`glpi-data`** : Stocke les fichiers nécessaires au fonctionnement de GLPI.

## Conclusion

Cette configuration Docker Compose met en place une infrastructure robuste et bien isolée pour gérer une application 3-tiers avec GLPI, MariaDB et Uptime Kuma. Grâce à l'utilisation de réseaux dédiés, de volumes persistants, sauvegarde automatique et de healthchecks.

