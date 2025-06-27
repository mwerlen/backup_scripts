#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# UUID du disque à vérifier
DISK_UUID="d950c733-e582-40fb-930f-602f82c5d0e4"
DEVICE_PATH="/dev/disk/by-uuid/$DISK_UUID"

# Vérifier si le disque est monté
if mount | grep -q "$DISK_UUID"; then
    echo "Le disque de backup (UUID=$DISK_UUID) est déjà monté. Pas d'arrêt du disque"
    exit 0
else
    # On vérifie l'état du disque avant de tenter de le mettre en veille.
    # La commande `hdparm -C` peut échouer si le disque ne la supporte pas.
    # Le `if` et la redirection de l'erreur `2>/dev/null` permettent de gérer ce cas.
    if DISK_STATE=$(hdparm -C "$DEVICE_PATH" 2>/dev/null) && echo "$DISK_STATE" | grep -q "active/idle"; then
        # Le disque est actif
        # On met le disque à l'arrêt
        hdparm -Y "$DEVICE_PATH"
        if [ $? -eq 0 ]; then
            # Tout est OK, on ne fait aucun log
            exit 0
        else
            echo "Erreur lors de l'exécution de l'arrêt du disque. Il faut vérifier le script $(realpath "$0")"
        fi
    else
        # Le disque est déjà à l'arrêt
        exit 0
    fi
fi
