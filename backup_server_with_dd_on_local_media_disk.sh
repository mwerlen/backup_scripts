#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

INTERNAL_BACKUP_DISK_MOUNT_DIR="/mnt/internal_backup"
BACKUP_FOLDER="${INTERNAL_BACKUP_DISK_MOUNT_DIR}/saveMax/server_dd"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [[ ! -d "${INTERNAL_BACKUP_DISK_MOUNT_DIR}" ]]; then
    echo "Mount point for internal backup disk is missing. Creating it"
    mkdir -p "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
fi

function mount_disk {
    echo "Montage du disque de sauvegarde interne"
    # d950c733-e582-40fb-930f-602f82c5d0e4 -> ../../sdb1 (le HDD interne)
    mount /dev/disk/by-uuid/d950c733-e582-40fb-930f-602f82c5d0e4 "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
}

function unmount_disk {
    echo "Démontage du disque de sauvegarde interne"
    umount "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
}

# Montage du disque de sauvegarde interne
trap unmount_disk SIGINT
trap unmount_disk EXIT
mount_disk

if [ ! -d "${BACKUP_FOLDER}" ]; then
    echo "Backup folder ($BACKUP__FOLDER) is not accessible"
    exit 2
fi

DATE=`date +%Y%m%d`
CMD="dd if=/dev/sda1 of=${BACKUP_FOLDER}/home_server_sda1-${DATE}.img bs=1024"
echo $CMD

START=$(date +%s)
$CMD
FINISH=$(date +%s)

echo "Backup with dd total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"
echo "Backup with dd total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup with DD" root@server.werlen.fr
