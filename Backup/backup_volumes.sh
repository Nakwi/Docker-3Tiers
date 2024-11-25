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
