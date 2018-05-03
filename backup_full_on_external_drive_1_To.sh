#!/bin/sh

START=$(date +%s)
rsync --archive --progress --safe-links --links /media/disk/* /mnt/backup_full/ --exclude downloads --exclude lost+found --exclude tempDownloads
FINISH=$(date +%s)
echo "Backup full on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"
echo "Backup full on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup full on external drive" root@server.werlen.fr

rm /mnt/backup_full/XX-Backup*
touch /mnt/backup_full/"XX-Backup from $(date '+%A, %d %B %Y, %T')"
