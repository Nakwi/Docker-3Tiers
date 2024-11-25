# 🚀 Introduction

Ce projet a pour objectif de mettre en place une infrastructure Docker pour héberger une application 3-tiers avec un tableau de bord centralisé et un service frontend. J'ai déployé un système composé des services suivants :

- **GLPI** : Une application de gestion de parc informatique.
- **MariaDB** : La base de données pour stocker les informations de GLPI.
- **Uptime Kuma** : Un outil de monitoring pour surveiller l'état des services.
- **Apache (Frontend)** : Un serveur web fournissant un tableau de bord centralisé pour accéder aux services.

L'architecture repose sur **Docker Compose**, avec des conteneurs interagissant dans un environnement réseau dédié pour garantir l'isolation et la sécurité des services. Un script de sauvegarde automatisé a également été mis en place pour garantir la pérennité des données et des *healthchecks*.

---

# 🏗️ Architecture du Projet

## Description générale

Le projet repose sur une architecture modulaire et bien isolée :

- **Encapsulation des services** : Chaque service est encapsulé dans un conteneur Docker.
- **Tableau de bord centralisé** : Le serveur Apache permet d'accéder facilement aux différents services.
- **Réseaux spécifiques** : Des réseaux dédiés gèrent les communications entre les services tout en limitant les interactions indésirables.
- **Persistance des données** : Les volumes Docker garantissent la sauvegarde et la pérennité des données critiques.

---

## 🌐 Structure Réseau

Pour garantir une isolation adéquate, les réseaux suivants ont été créés :

- **frontend-network** : Permet aux utilisateurs d'accéder à GLPI, Uptime Kuma, et au serveur Apache (frontend).
- **bdd-network** : Relie GLPI et MariaDB de manière sécurisée, empêchant tout accès externe à la base de données.
- **backend-network** : Permet les communications internes pour le monitoring avec Uptime Kuma.

---

## Schéma de Connectivité

| Source         | Destination  | Ping possible ? |
|----------------|--------------|-----------------|
| **GLPI**       | MariaDB      | ✅ Oui          |
| **GLPI**       | Uptime Kuma  | ✅ Oui          |
| **MariaDB**    | GLPI         | ✅ Oui          |
| **MariaDB**    | Uptime Kuma  | ❌ Non          |
| **Uptime Kuma**| GLPI         | ✅ Oui (HTTP)   |
| **Uptime Kuma**| MariaDB      | ❌ Non          |
| **Frontend**   | GLPI         | ✅ Oui          |
| **Frontend**   | Uptime Kuma  | ✅ Oui          |
| **Frontend**   | MariaDB      | ❌ Non          |

---

# 📜 Structure du Projet

## Arborescence

Le projet est structuré pour séparer les configurations, les scripts et les sauvegardes. Voici l'organisation des fichiers et dossiers principaux :

```plaintext
├── docker-compose.yaml        
├── glpi/                        
│   └── Dockerfile               
├── apache/                 
│   └── index.html               
├── backup/                      
│   └── backup_volumes.sh        
└── docker-backups/ 
```
# 📂 Structure des Fichiers

- **docker-compose.yaml** : Orchestre les conteneurs et définit les réseaux, volumes, et services.
- **glpi/** : Contient les fichiers nécessaires pour construire l'image Docker de GLPI.
- **apache-html/** : Contient les fichiers statiques pour le serveur Apache (comme `index.html`).
- **backup/** : Regroupe les scripts pour les sauvegardes automatisées.
- **docker-backups/** : Stocke les données archivées et les snapshots de sauvegarde.

---

# Détails des Services

## 1. 🎫 Image Docker GLPI

Le conteneur **GLPI** est construit à partir d’un Dockerfile personnalisé. Ce fichier intègre les éléments suivants :

- **Dépendances nécessaires** : Installation des extensions PHP requises.
- **Téléchargement** : Récupération de la dernière version stable de GLPI.
- **Configuration des permissions** : Configuration des droits pour assurer le bon fonctionnement de l'application.
```
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

---

## 2. 🔗 Image Docker Apache

Le service **Apache** est basé sur l'image officielle `httpd`. Voici les détails de la configuration :

### Configuration du Service Apache

- **Image** : `httpd:latest`
- **Nom du Conteneur** : `tp-apache-frontend`
- **Ports** : 
  - Redirection du port `80` du conteneur vers le port `4000` de l'hôte.
- **Volumes** :
  - Mappage des fichiers HTML depuis `/home/ryan/TP/apache` ou via un volume nommé `apache-data`.
- **Réseaux** :
  - Connecté au réseau `frontend-network`.

Cette configuration permet de personnaliser facilement le tableau de bord centralisé, accessible via le serveur Apache.
```
  apache:
    image: httpd:latest
    container_name: tp-apache-frontend
    ports:
      - "4000:80"
    volumes:
      - /home/ryan/TP/apache:/usr/local/apache2/htdocs/
    networks:
      - frontend-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://192.168.0.157:4000/index.html"]
      interval: 30s
      timeout: 10s
      retries: 3
```
![image](https://github.com/user-attachments/assets/30053ae2-cbde-42f9-893e-6358b3fc106b)
## 3. 🩺 Healthchecks

Des *healthchecks* ont été ajoutés pour chaque conteneur afin de surveiller leur état et garantir leur bon fonctionnement. Voici les vérifications effectuées :

- **GLPI** : Vérifie que l'interface web est accessible via HTTP.
- **MariaDB** : Vérifie que le service de base de données répond aux connexions.
- **Uptime Kuma** : Vérifie que le tableau de bord est accessible.
- **Apache** : Vérifie que le tableau de bord centralisé est accessible.

### Exemple de Configuration d'un Healthcheck

Voici un exemple de configuration pour vérifier l'accès au tableau de bord d'**Uptime Kuma** :
```
    healthcheck:
      test: ["CMD", "curl", "-f", "http://192.168.0.157:3001/dashboard"]
      interval: 30s
      timeout: 10s
      retries: 3
```
## 4. 💾 Script de Sauvegarde

Un script de sauvegarde automatisé a été mis en place pour préserver les données critiques de tous les volumes Docker, y compris celui utilisé par le serveur Apache.

### Fonctionnalités du Script

- Sauvegarde des volumes Docker dans un dossier dédié (`docker-backups`).
- Compression des données pour économiser de l'espace disque.
- Planification possible via **cron** pour des sauvegardes régulières.
- Logs générés pour suivre l'état des sauvegardes.

```
#!/bin/bash

# Répertoire de sauvegarde
BACKUP_DIR="/home/ryan/TP/docker-backups"
DATE=$(date +'%Y-%m-%d')

# Liste des volumes Docker à sauvegarder
VOLUMES=("tp_db-data" "tp_uptime-kuma-data" "glpi-data")

# Fichier spécifique à sauvegarder
APACHE_FILE="/home/ryan/TP/apache/index.html"

# Création du répertoire de sauvegarde s'il n'existe pas
mkdir -p "$BACKUP_DIR"

# Sauvegarde des volumes Docker
for VOLUME in "${VOLUMES[@]}"; do
    echo "Sauvegarde du volume $VOLUME..."
    docker run --rm \
        -v ${VOLUME}:/volume \
        -v ${BACKUP_DIR}:/backup \
        alpine \
        tar czf /backup/${VOLUME}_${DATE}.tar.gz -C /volume .
done

# Sauvegarde du fichier Apache
if [ -f "$APACHE_FILE" ]; then
    echo "Sauvegarde du fichier Apache : $APACHE_FILE..."
    tar czf "$BACKUP_DIR/apache_index_${DATE}.tar.gz" -C "$(dirname "$APACHE_FILE")" "$(basename "$APACHE_FILE")"
else
    echo "Fichier Apache non trouvé : $APACHE_FILE"
fi

echo "Sauvegarde terminée ! Les fichiers sont dans $BACKUP_DIR"

```
### Automatisation avec Cron

Pour automatiser cette tâche, une ligne de commande Cron a été ajoutée. Elle exécute le script tous les jours à 3h du matin :

```bash
0 3 * * * /bin/bash /home/ryan/TP/Backup/backup_volumes.sh
```
# 🖧 Docker Compose Configuration

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
      test: ["CMD", "curl", "-f", "http://192.168.0.157/glpi"]
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
      test: ["CMD", "mysqladmin", "ping", "-h", "192.168.0.157", "-u", "root", "--password=rootpassword"]
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

  apache:
    image: httpd:latest
    container_name: tp-apache-frontend
    ports:
      - "4000:80"
    volumes:
      - /home/ryan/TP/apache:/usr/local/apache2/htdocs/
    networks:
      - frontend-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://192.168.0.157:4000/index.html"]
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
---

### **MariaDB**
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

## Volumes

Des volumes sont utilisés pour assurer la persistance des données :
- **`db-data`** : Stocke les données de MariaDB.
- **`uptime-kuma-data`** : Stocke les configurations et logs d'Uptime Kuma.
- **`glpi-data`** : Stocke les fichiers nécessaires au fonctionnement de GL

## Conclusion

Cette configuration Docker Compose met en place une infrastructure robuste et bien isolée pour gérer une application 3-tiers avec GLPI, MariaDB, Uptime Kuma & un frontend Apache. Grâce à l'utilisation de réseaux dédiés, de volumes persistants, sauvegarde automatique et de healthchecks.
