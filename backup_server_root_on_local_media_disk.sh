#!/bin/sh

START=$(date +%s)
rsync -aAXv /* /media/disk/saveMax/server/ --exclude /dev/ --exclude /proc/ --exclude /sys/ --exclude /tmp/ --exclude /run/ --exclude /mnt/ --exclude /media/ --exclude lost+found
FINISH=$(date +%s)
echo "Backup on local disk total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" 
echo "Backup on local disk total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup on local drive" root@server.werlen.fr

rm /media/disk/saveMax/server/XX-Backup*
touch /media/disk/saveMax/server/"XX-Backup from $(date '+%A, %d %B %Y, %T')"
