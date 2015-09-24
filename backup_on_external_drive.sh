#!/bin/sh

START=$(date +%s)
rsync --archive --progress --safe-links --links /media/disk/* /mnt/backup/ --exclude downloads --exclude lost+found --exclude movies --exclude saveJean --exclude series --exclude tempDownloads
FINISH=$(date +%s)
echo "Backup on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"
echo "Backup on external drive total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup on external drive" root@server.werlen.fr

rm /mnt/backup/XX-Backup*
touch /mnt/backup/"XX-Backup from $(date '+%A, %d %B %Y, %T')"
