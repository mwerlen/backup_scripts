#!/bin/bash

DATE=`date +%Y%m%d`
CMD="dd if=/dev/sda of=/media/disk/saveMax/server_dd/home_server_sda-${DATE}.img bs=1024"
echo $CMD

START=$(date +%s)
$CMD
FINISH=$(date +%s)

echo "Backup with dd total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"
echo "Backup with dd total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | mail -s "Backup with DD" root@server.werlen.fr
