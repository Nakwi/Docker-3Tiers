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
