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
