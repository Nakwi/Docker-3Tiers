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
        tar czf /backup/${VOLUME}_${DATE}.tar.gz -C /volume .
done

echo "Sauvegarde terminée ! Les fichiers sont dans $BACKUP_DIR"
