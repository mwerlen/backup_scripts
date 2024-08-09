#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

INTERNAL_BACKUP_DISK_MOUNT_DIR="/mnt/internal_backup"
EXTERNAL_BACKUP_DISK_MOUNT_DIR="/mnt/backup_full"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [[ -z "${STY:-}" ]]; then
    echo "You are not running this backup in a GNU screen."
    echo "You perhaps forget to run with sudo -E to keep your env variables"
    read -p "Press [Enter] key to start backup anyway..."
fi

if [[ ! -d "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}" ]]; then
    echo "Mount point for external backup disk is missing. Creating it"
    mkdir -p "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}"
fi

if [[ ! -d "${INTERNAL_BACKUP_DISK_MOUNT_DIR}" ]]; then
    echo "Mount point for internal backup disk is missing. Creating it"
    mkdir -p "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
fi

function mount_disks {
    echo "Montage du disque de sauvegarde interne"
    # d950c733-e582-40fb-930f-602f82c5d0e4 -> ../../sdb1 (le HDD interne)
    mount /dev/disk/by-uuid/d950c733-e582-40fb-930f-602f82c5d0e4 "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
    
    echo "Montage du disque de sauvegarde externe"
    cryptsetup luksOpen /dev/disk/by-uuid/bdc2698b-582c-4313-8482-563b9c9b52a6 backup_full
    mount /dev/mapper/backup_full "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}"
}

function unmount_disks {
    echo "Démontage du disque de sauvegarde interne"
    umount "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
    
    echo "Démontage du disque de sauvegarde externe"
    umount "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}"
    cryptsetup luksClose backup_full
}

# Montage des disques de sauvegarde interne et externe
trap unmount_disks SIGINT
trap unmount_disks EXIT
mount_disks

echo "All disks mounted"
echo "Starting backup. You will receive a mail when backup is done."

START="$(date +%s)"
rsync-no-vanished \
    --archive \
    --delete --delete-before --delete-excluded \
    --progress \
    --safe-links --links \
    --one-file-system \
    --exclude "lost+found" \
    --exclude "tempDownloads" \
    --exclude "saveMax/server_backup" \
    /media/disk/* \
    "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}"

rsync-no-vanished \
    --archive \
    --delete --delete-before --delete-excluded \
    --progress \
    --safe-links --links \
    --one-file-system \
    --exclude "lost+found" \
    "${INTERNAL_BACKUP_DISK_MOUNT_DIR}/saveMax/server_backup" \
    "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}/saveMax/server_backup"

FINISH="$(date +%s)"

echo "Backup full on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"
echo "Backup full on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup full on external drive" root@server.werlen.fr

rm -f "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}/XX-Backup"*
touch "${EXTERNAL_BACKUP_DISK_MOUNT_DIR}/XX-Backup from $(date '+%A, %d %B %Y, %T')"

echo "Done !"
