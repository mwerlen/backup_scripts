#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "You must be root to launch backup" 2>&1
  exit 1
fi

START=$(date +%s)
echo "Starting flick_uploadr. A mail will be send at the end."
cd /usr/local/src/flickr_uploadr/
# reset log
echo "Lancement par le script backup_photos_on_flickr.sh" > /var/log/uploadr.log
python -u /usr/local/src/flickr_uploadr/uploadr.py
FINISH=$(date +%s)

echo "Backup all photos on Flickr - total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds" | tee -a /var/log/uploadr.log

cat /var/log/uploadr.log | mail -s "Backup on flickR finished" root@server.werlen.fr
