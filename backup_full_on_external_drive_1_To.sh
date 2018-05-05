#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

mkdir -p /mnt/backup_full
cryptsetup luksOpen /dev/disk/by-uuid/bdc2698b-582c-4313-8482-563b9c9b52a6 backup_full
mount /dev/mapper/backup_full /mnt/backup_full/

echo "Disk mounted"

START=$(date +%s)
rsync --archive --progress --safe-links --links --one-file-system /media/disk/* /mnt/backup_full/ --exclude lost+found
FINISH=$(date +%s)
echo "Backup full on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"
echo "Backup full on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup full on external drive" root@server.werlen.fr

rm -f /mnt/backup_full/XX-Backup*
touch /mnt/backup_full/"XX-Backup from $(date '+%A, %d %B %Y, %T')"

umount /mnt/backup_full
cryptsetup luksClose backup_full

echo "Done !"
