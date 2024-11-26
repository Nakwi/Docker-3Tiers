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
    echo "Sauvegarde du fichier Nginx : $NGINXFILE..."
    tar czf "$BACKUP_DIR/nginx_index_${DATE}.tar.gz" -C "$(dirname "$NGINX_FILE")" "$(basename "$NGINX_FILE")"
else
    echo "Fichier Nginx non trouvé : $NGINX_FILE"
fi

echo "Sauvegarde terminée ! Les fichiers sont dans $BACKUP_DIR"
