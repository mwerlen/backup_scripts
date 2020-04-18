#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

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

mkdir -p /mnt/backup
cryptsetup luksOpen /dev/disk/by-uuid/3919452e-9ba5-496e-9c96-e91d1672eb5c backup
mount /dev/mapper/backup /mnt/backup

echo "Disk mounted"
echo "Starting backup. You will receive a mail when backup is done."

START=$(date +%s)
rsync-no-vanished \
    --archive \
    --delete --delete-before --delete-excluded \
    --progress \
    --safe-links --links \
    --one-file-system \
    --exclude "lost+found" \
    --exclude "downloads" \
    --exclude "movies" \
    --exclude "saveJean" \
    --exclude "saveMax" \
    --exclude "series" \
    --exclude "tempDownloads" \
    --exclude "torrents" \
    /media/disk/* /mnt/backup/
FINISH=$(date +%s)
echo "Backup on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"
echo "Backup on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup on external drive" root@server.werlen.fr

rm -f /mnt/backup/XX-Backup*
touch /mnt/backup/"XX-Backup from $(date '+%A, %d %B %Y, %T')"

umount /mnt/backup
cryptsetup luksClose backup

echo "Done !"
