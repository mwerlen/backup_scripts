#!/bin/sh

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

rm /mnt/backup/XX-Backup*
touch /mnt/backup/"XX-Backup from $(date '+%A, %d %B %Y, %T')"
