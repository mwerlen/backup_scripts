#!/bin/sh
# strict mode on
set -euo pipefail
IFS=$'\n\t'

function mount_disk {
    echo "Montage de la partition media du SSD"
    mount /dev/disk/by-uuid/7ca282ed-e8f2-4f8e-90a8-e938b395a347 "/mnt/ssd_media"
}

function unmount_disk {
    echo "Démontage de la partition media du SSD"
    umount "/mnt/ssd_media"
}

if [[ $EUID -ne 0 ]]; then
    echo "You must be root to launch backup script" 2>&1
    exit 1
fi

if [[ -z "${STY:-}" ]]; then
    echo "You are not running this backup in a GNU screen."
    echo "You perhaps forget to run with sudo -E to keep your env variables"
    read -p "Press [Enter] key to start backup anyway..."
fi

if [[ ! -d "/mnt/ssd_media" ]]; then
    echo "Mount point for internal backup disk is missing. Creating it"
    mkdir -p "/mnt/ssd_media"
fi

# Montage du disque de sauvegarde interne
trap unmount_disk SIGINT
trap unmount_disk EXIT
mount_disk

START=$(date +%s)
rsync-no-vanished  \
    --recursive \
    --one-file-system \
    --links --hard-links \
    --perms --executability \
    --times --atimes --open-noatime \
    --group --owner \
    --acls --xattrs \
    --delete-before \
    --no-compress \
    --verbose \
    --exclude "saveMax/server_backup" \
    --exclude lost+found \
    /media/disk/ \
    /mnt/ssd_media
FINISH=$(date +%s)

echo "Copy on local SSD disk total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" 
echo "Copy on local SSD disk total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Copy harddrive on local SSD drive" root@server.werlen.fr
