# 🚀 Description de la solution

La solution repose sur une architecture en plusieurs services :

- **Frontend** : Un serveur web Nginx jouant le rôle de reverse proxy et de point d'entrée unique. Il redirige les requêtes vers les services backend, tout en offrant une interface utilisateur personnalisée via une page HTML.
- **Backend** : Le service GLPI, déployé dans un conteneur Docker dédié, accessible uniquement via le reverse proxy.
- **Base de données** : MariaDB, utilisée pour stocker les données du backend GLPI.
- **Monitoring** : Uptime Kuma, un outil de monitoring des services, également intégré dans un conteneur Docker.

## Sommaire
1. 🌐 Réseaux et Isolation des Services
2. 🏗️ Structure du Projet
3. 🖥️ Frontend
4. 🔧 Backend
5. 🗄️ Base de Données (BDD)
6. 📱 Monitoring
7. 🩺 Healthchecks
8. 💾 Script de Sauvegarde
9. 💾 Script de Restauration
10. 💾 Script de Mise à Jour Automatique des Images Docker
11. 📊 Tableau récapitulati
---
## 🌐 Réseaux et Isolation des Services

L'infrastructure Docker repose sur trois réseaux virtuels distincts pour garantir l'isolation des services et la sécurité des échanges entre eux. Chaque réseau a un rôle bien défini :

- **Frontend-Network** : Ce réseau est utilisé par le serveur web Nginx et Uptime-Kuma, les services accessibles aux utilisateurs finaux. Il sert de point d'entrée pour les requêtes et communique avec les autres services selon les besoins.
- **Backend-Network** : Réseau privé pour la communication entre les services backend comme GLPI. Ce réseau n'est pas directement accessible depuis l'extérieur.
- **BDD-Network** : Réseau dédié aux échanges sécurisés entre la base de données MariaDB et les services autorisés comme GLPI. Il isole la base de données des autres services pour renforcer la sécurité.

#### Communication entre les réseaux et les services

Chaque service est connecté à un ou plusieurs réseaux en fonction de ses besoins de communication. L'accès entre les services est strictement limité pour éviter les interactions non autorisées.

| **Service**       | **Frontend-Network** | **Backend-Network** | **BDD-Network** | **Peut communiquer avec**                              |
|--------------------|----------------------|---------------------|-----------------|-------------------------------------------------------|
| **Nginx**          | ✅                   | ❌                  | ❌              | GLPI (via Frontend-Network)                           |
| **GLPI**           | ✅                   | ✅                  | ✅              | Nginx (Frontend), MariaDB (BDD), Uptime Kuma (Backend) |
| **MariaDB**        | ❌                   | ❌                  | ✅              | GLPI (via BDD-Network)                                |
| **Uptime Kuma**    | ✅                   | ✅                  | ❌              | GLPI (via Backend-Network)                            |
---
#### Schéma des réseaux et communication

- **Nginx** : Accessible depuis le réseau Frontend-Network pour rediriger les requêtes vers GLPI.
- **GLPI** : Pont entre les trois réseaux pour interagir avec le proxy (Frontend-Network), la base de données (BDD-Network), et le monitoring (Backend-Network).
- **MariaDB** : Complètement isolée à l'intérieur du BDD-Network, accessible uniquement par GLPI.
- **Uptime Kuma** : Présent dans le Backend-Network et Frontend-Network pour le monitoring et l'accès utilisateur.
---
## 🏗️ Structure du Projet

L'arborescence de l'infrastructure est organisée pour une gestion claire et une maintenance simplifiée. Chaque dossier et fichier a un rôle bien défini.


```
├── docker-compose.yaml      # Fichier principal pour orchestrer les conteneurs et les réseaux.
├── glpi/                          
│   └── Dockerfile           # Fichier Dockerfile pour créer l'image Docker de GLPI.         
├── nginx/                   # Dossier pour la configuration du serveur Nginx. 
│   └── index.html           # Page d'accueil HTML personnalisée pour le frontend.
      └── proxy-conf.conf    # Configuration du reverse proxy Nginx.
├── scripts/                 # Dossier pour les scripts d'administration et de maintenance.
│   └── backup_volumes.sh    # Script pour sauvegarder les volumes Docker.
      └── restore_volumes.sh # Script pour restaurer les volumes Docker. 
       └── maj_images.sh     # Script pour mettre à jour les images Docker
└── docker-backups/          # Dossier pour stocker les sauvegardes des volumes.
```
---
# 🖥️ Frontend

Le frontend de l'infrastructure est pris en charge par un conteneur **Nginx**, configuré comme serveur web et reverse proxy. Sa configuration est définie dans le fichier `docker-compose.yaml` et complétée par des fichiers de configuration spécifiques.

#### Configuration dans le `docker-compose.yaml`

```yaml
nginx:
  image: nginx:latest
  container_name: tp-nginx-frontend
  ports:
    - "4000:80"
  volumes:
    - /home/ryan/TP/nginx/:/usr/share/nginx/html:ro
    - /home/ryan/TP/nginx/proxy-config.conf:/etc/nginx/conf.d/default.conf:ro
  networks:
    - frontend-network
```



### Image
- **Utilisation :**  
  L'image officielle `nginx:latest` est utilisée, garantissant une version stable et régulièrement mise à jour du serveur web.

### Nom du conteneur
- **Nom :**  
  Le conteneur est nommé **`tp-nginx-frontend`** pour une identification simple et claire dans l'infrastructure.

### Ports
- **Configuration :**  
  Le port **4000** de l'hôte est mappé au port **80** du conteneur Nginx, permettant l'accès à l'interface via l'adresse suivante :  
  `http://<adresse-ip-du-serveur>:4000`

### Volumes
- **Page HTML statique :**  
  Le volume **`/home/ryan/TP/nginx/`** est monté sur **`/usr/share/nginx/html`** dans le conteneur. Cela permet à Nginx de servir un fichier `index.html` personnalisé comme page d'accueil.  
- **Configuration du proxy :**  
  Le fichier de configuration spécifique au reverse proxy (**`proxy-config.conf`**) est monté en **lecture seule** dans le dossier **`/etc/nginx/conf.d/`**. Ce fichier définit les règles de redirection des requêtes vers d'autres services.

### Réseau
- **Configuration :**  
  Le conteneur Nginx est connecté au réseau **`frontend-network`**, isolé des autres réseaux, garantissant que seules les requêtes front-end y circulent.

---
# 🔧 Backend

Le backend de l'infrastructure est pris en charge par le conteneur **GLPI**, une application dédiée à la gestion des services informatiques. Il constitue le cœur du système, reliant le frontend et la base de données.

## Configuration dans le `docker-compose.yaml`

```yaml
glpi:
  build:
    context: ./glpi
  container_name: tp-glpi-1
  volumes:
    - glpi-data:/var/www/html
  networks:
    - frontend-network
    - bdd-network
```


### Image
- **Utilisation :**  
  L'image de GLPI est construite à partir du **Dockerfile** situé dans le dossier **`./glpi`**. Cette méthode permet de personnaliser l'environnement et de s'assurer que toutes les dépendances nécessaires à GLPI sont incluses.

### Nom du conteneur
- **Nom :**  
  Le conteneur est nommé **`tp-glpi-1`** pour une identification simple dans l'infrastructure Docker. Ce nom facilite la gestion et le débogage des conteneurs.

### Volumes
- **Configuration :**  
  - Le volume nommé **`glpi-data`** est monté sur le chemin **`/var/www/html`** dans le conteneur GLPI.  
  - Ce volume est utilisé pour stocker les fichiers persistants de l'application GLPI, tels que les configurations, les plugins, et les données téléversées.

### Réseaux
- **`frontend-network` :**  
  Permet à GLPI de communiquer avec le serveur Nginx, qui agit comme reverse proxy. Cela garantit que le service backend est accessible uniquement via le frontend.
- **`bdd-network` :**  
  Permet à GLPI de communiquer avec le service MariaDB pour accéder aux données stockées.
---
# 🗄️ Base de Données (BDD)

La base de données de l'infrastructure est gérée par le conteneur **MariaDB**, qui assure le stockage et la gestion des données nécessaires à l'application GLPI.

## Configuration dans le `docker-compose.yaml`

```yaml
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
```
### Image
- **Utilisation :**  
  L'image **`mariadb:10.6`** est utilisée pour garantir un environnement de base de données stable et performant.

### Nom du conteneur
- **Nom :**  
  Le conteneur est nommé **`tp-mariadb-1`** pour une identification facile dans l'infrastructure.

### Ports
- **Configuration :**  
  Le port **3306** est mappé entre l'hôte et le conteneur, permettant l'accès à la base de données depuis d'autres services connectés au réseau.

### Variables d'environnement
- **`MYSQL_ROOT_PASSWORD` :** Définit le mot de passe pour l'utilisateur root.  
- **`MYSQL_DATABASE` :** Crée une base de données nommée **`glpidb`** lors du premier démarrage du conteneur.  
- **`MYSQL_USER` et `MYSQL_PASSWORD` :**  
  Créent un utilisateur nommé **`glpiuser`** avec le mot de passe **`glpipassword`**, doté des autorisations nécessaires pour accéder à **`glpidb`**.

### Volumes
- **Configuration :**  
  Le volume nommé **`db-data`** est monté sur le chemin **`/var/lib/mysql`** dans le conteneur. Cela garantit la persistance des données, même si le conteneur est recréé.

### Réseau
- **`bdd-network` :**  
  Le conteneur MariaDB est uniquement connecté à ce réseau, garantissant qu'il est isolé des autres services et uniquement accessible par GLPI.
---
# 📱 Monitoring

Le monitoring de l'infrastructure est assuré par le conteneur **Uptime Kuma**, un outil performant et convivial permettant de surveiller l'état des services.

## Configuration dans le `docker-compose.yaml`

```yaml
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
```

### Image
- **Utilisation :**  
  L'image officielle **`louislam/uptime-kuma:latest`** est utilisée pour garantir l'accès aux dernières fonctionnalités et mises à jour.

### Nom du conteneur
- **Nom :**  
  Le conteneur est nommé **`tp-uptime-kuma-1`** pour une identification claire au sein de l'infrastructure.

### Ports
- **Configuration :**  
  Le port **3001** est mappé entre l'hôte et le conteneur, permettant l'accès à l'interface web d'Uptime Kuma via :  
  `http://<adresse-ip-du-serveur>:3001`

### Volumes
- **Configuration :**  
  Le volume nommé **`uptime-kuma-data`** est monté sur le chemin **`/app/data`** dans le conteneur, garantissant la persistance des configurations et des données de surveillance.

### Réseaux
- **`backend-network` :**  
  Permet à Uptime Kuma de surveiller les services backend, comme GLPI.  
- **`frontend-network` :**  
  Permet à Uptime Kuma d'être accessible depuis le réseau frontend pour l'interface utilisateur.
---
# 🩺 Healthchecks

Des *healthchecks* ont été ajoutés pour chaque conteneur afin de surveiller leur état et garantir leur bon fonctionnement. Voici les vérifications effectuées :

- **GLPI** : Vérifie que l'interface web est accessible via HTTP.
- **MariaDB** : Vérifie que le service de base de données répond aux connexions.
- **Uptime Kuma** : Vérifie que le tableau de bord est accessible.
- **Nginx** : Vérifie que le tableau de bord centralisé est accessible.

### Exemple de Configuration d'un Healthcheck

Voici un exemple de configuration pour vérifier l'accès au tableau de bord d'**Uptime Kuma** :
```
    healthcheck:
      test: ["CMD", "curl", "-f", "http://192.168.0.157:3001/dashboard"]
      interval: 30s
      timeout: 10s
      retries: 3
```
---
# 💾 Script de Sauvegarde

Ce script permet de sauvegarder les volumes Docker et un fichier spécifique (comme la page d'accueil Nginx) dans un répertoire de sauvegarde local. Chaque sauvegarde est horodatée pour faciliter la gestion.

### Fonctionnalités du Script
1. **Sauvegarde des volumes Docker** :
   - Sauvegarde les volumes spécifiés dans un fichier compressé `.tar.gz`.
   - Utilise une image **alpine** pour exécuter les commandes dans un conteneur temporaire.

2. **Sauvegarde du fichier Nginx** :
   - Sauvegarde le fichier `index.html` situé dans le répertoire Nginx.

3. **Gestion des répertoires** :
   - Vérifie si le répertoire de sauvegarde existe et le crée si nécessaire.

### Contenu du Script

```bash
#!/bin/bash

# Répertoire de sauvegarde
BACKUP_DIR="/home/ryan/TP/docker-backups"
DATE=$(date +'%Y-%m-%d')

# Liste des volumes Docker à sauvegarder
VOLUMES=("tp_db-data" "tp_uptime-kuma-data" "glpi-data")

# Fichier spécifique à sauvegarder
NGINX_FILE="/home/ryan/TP/nginx/index.html"

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

# Sauvegarde du fichier Nginx
if [ -f "$NGINX_FILE" ]; then
    echo "Sauvegarde du fichier Nginx : $NGINX_FILE..."
    tar czf "$BACKUP_DIR/nginx_index_${DATE}.tar.gz" -C "$(dirname "$NGINX_FILE")" "$(basename "$NGINX_FILE")"
else
    echo "Fichier Nginx non trouvé : $NGINX_FILE"
fi

echo "Sauvegarde terminée ! Les fichiers sont dans $BACKUP_DIR"

```

Pour automatiser cette tâche, une ligne de commande Cron a été ajoutée. Elle exécute le script tous les jours à 3h du matin :

```bash
0 3 * * * /bin/bash /home/ryan/TP/scripts/backup_volumes.sh
```
---
# 💾 Script de Restauration des Volumes et Fichiers Docker

Ce script permet de restaurer les volumes Docker et un fichier spécifique (comme le fichier Nginx) à partir des sauvegardes existantes. L'utilisateur doit spécifier la date de la sauvegarde à restaurer.

### Fonctionnement

1. **Demande de la date de sauvegarde** :
   - L'utilisateur entre une date au format `AAAA_MM_JJ` (exemple : `2024_11_26`).

2. **Validation de la date** :
   - Le script vérifie que le format saisi est correct.
   - La date est convertie en format compatible avec les noms des fichiers de sauvegarde (remplacement de `_` par `-`).

3. **Restauration des volumes Docker** :
   - Pour chaque volume spécifié, le script recherche un fichier de sauvegarde correspondant à la date.
   - Si un fichier est trouvé, son contenu est restauré dans le volume.

4. **Restauration du fichier Nginx** :
   - Si une sauvegarde de `index.html` existe pour la date spécifiée, elle est restaurée dans le répertoire de Nginx.

### Contenu du Script

```bash
#!/bin/bash

# Répertoire des sauvegardes
BACKUP_DIR="/home/ryan/TP/docker-backups"

# Demande de la date à l'utilisateur
read -p "Entrez la date de la sauvegarde à restaurer (format AAAA_MM_JJ) : " DATE

# Validation du format de la date
if [[ ! "$DATE" =~ ^[0-9]{4}_[0-9]{2}_[0-9]{2}$ ]]; then
    echo "Erreur : le format de la date doit être AAAA_MM_JJ (exemple : 2024_11_26)"
    exit 1
fi

# Conversion de la date au format utilisé dans les fichiers de sauvegarde (remplace `_` par `-`)
DATE_FILE_FORMAT=$(echo "$DATE" | sed 's/_/-/g')

# Liste des volumes Docker à restaurer
VOLUMES=("tp_db-data" "tp_uptime-kuma-data" "glpi-data")

# Vérification et restauration des volumes Docker
for VOLUME in "${VOLUMES[@]}"; do
    BACKUP_FILE="$BACKUP_DIR/${VOLUME}_${DATE_FILE_FORMAT}.tar.gz"
    if [ -f "$BACKUP_FILE" ]; then
        echo "Restauration du volume $VOLUME depuis $BACKUP_FILE..."
        docker run --rm \
            -v ${VOLUME}:/volume \
            -v ${BACKUP_DIR}:/backup \
            alpine \
            tar xzf /backup/${VOLUME}_${DATE_FILE_FORMAT}.tar.gz -C /volume
        echo "Volume $VOLUME restauré avec succès."
    else
        echo "Aucune sauvegarde trouvée pour $VOLUME à la date $DATE."
    fi
done

# Restauration du fichier Nginx
NGINX_FILE="$BACKUP_DIR/nginx_index_${DATE_FILE_FORMAT}.tar.gz"
if [ -f "$NGINX_FILE" ]; then
    echo "Restauration du fichier Nginx depuis $NGINX_FILE..."
    tar xzf "$NGINX_FILE" -C /home/ryan/TP/nginx/
    echo "Fichier Nginx restauré avec succès."
else
    echo "Aucune sauvegarde Nginx trouvée pour la date $DATE."
fi

echo "Restauration terminée."
```
# 💾 Script de Mise à Jour Automatique des Images Docker

Ce script permet de mettre à jour automatiquement les images Docker utilisées par l'infrastructure. Il effectue un `pull` des dernières versions des images spécifiées.

### Fonctionnement

1. **Liste des images à mettre à jour** :
   - Les images Docker à mettre à jour sont définies dans un tableau, avec leurs noms et tags respectifs.

2. **Mise à jour des images** :
   - Le script parcourt chaque image dans la liste et exécute une commande `docker pull` pour télécharger la dernière version.

3. **Rapport d'état** :
   - Le script affiche une confirmation pour chaque image mise à jour et un résumé final.

### Contenu du Script

```bash
#!/bin/bash

# Liste des images à mettre à jour
IMAGES=(
  "mariadb:10.6"
  "louislam/uptime-kuma:latest"
  "httpd:latest"
)

# Mise à jour des images
for IMAGE in "${IMAGES[@]}"; do
  echo "Mise à jour de l'image : $IMAGE"
  docker pull "$IMAGE"
done

echo "Toutes les images ont été mises à jour."
```
# Conclusion

Cette infrastructure Docker offre une solution robuste, modulaire et facilement maintenable pour déployer et gérer plusieurs services interconnectés, notamment :
- **GLPI** pour la gestion des services informatiques,
- **MariaDB** pour le stockage et la gestion des données,
- **Uptime Kuma** pour le monitoring,
- **Nginx** pour servir de reverse proxy et de point d'entrée.

Les scripts de sauvegarde, de restauration et de mise à jour assurent une gestion simplifiée et une fiabilité accrue, même en cas de panne ou de mise à jour des services. Grâce à cette organisation, l'infrastructure peut évoluer pour répondre à de nouveaux besoins tout en garantissant la sécurité et la performance.

---

## Tableau récapitulatif

- **GLPI**  
  - **Lien d'accès :** [http://192.168.0.157:4000/glpi](http://192.168.0.157:4000/glpi)  
  - **Volume Docker :** `glpi-data`

- **MariaDB**  
  - **Lien d'accès :** *Non accessible directement (BDD)*  
  - **Volume Docker :** `tp_db-data`

- **Uptime Kuma**  
  - **Lien d'accès :** [http://192.168.0.157:3001/dashboard](http://192.168.0.157:3001/dashboard)  
  - **Volume Docker :** `tp_uptime-kuma-data`

- **Nginx (Frontend)**  
  - **Lien d'accès :** [http://192.168.0.157:4000/index.html](http://192.168.0.157:4000/index.html)  
  - **Volume Docker :** *Aucun volume dédié*

Avec cette infrastructure, vous disposez d'un système scalable, sécurisé et capable d'être maintenu efficacement grâce à l'automatisation et aux scripts mis en place.

