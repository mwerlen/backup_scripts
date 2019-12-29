#!/bin/bash
set -uo pipefail
IFS=$'\n\t'

DIRECTORY="/spock_backup/backup_on_$(date --rfc-3339=date)/"
USER="mwerlen"
SERVER="server.werlen.fr"
CTRL_SOCKET="$HOME/.ssh/backup-ctrl-socket"
RSYNC_SHARE="saveMax"
PORT=1873
export RSYNC_PASSWORD="rBHx7nAy4tB9qfMVGhbsp5J"

# Make sure this script is not run as root
if [[ $EUID -eq 0 ]]; then
  echo "This script must NOT be run as root" 1>&2
  exit 2
fi

if [ -f $CTRL_SOCKET ]; then
    echo "Old connection socket detected. Please delete $CTRL_SOCKET"
    exit -1
fi

echo "Establishing tunnel..."

ssh -M \
    -fnNT \
    -S $CTRL_SOCKET \
    -L $PORT:localhost:$PORT  \
    $USER@$SERVER

echo "Connection is ok"
ssh -S $CTRL_SOCKET -O check $USER@$SERVER

echo "Starting rsync"
START=$(date +%s)

sudo rsync --port=$PORT \
    --recursive \
    --times \
    --specials \
    --compress \
    --verbose \
    --safe-links \
    --links \
    --one-file-system \
    --exclude /dev/ \
    --exclude /proc/ \
    --exclude /sys/ \
    --exclude /tmp/ \
    --exclude /run/ \
    --exclude /mnt/ \
    --exclude /media/ \
    --exclude lost+found \
    --exclude /home/mwerlen/Music \
    --exclude /home/mwerlen/Videos \
    --exclude /home/mwerlen/projects \
    --exclude /home/mwerlen/.PlayOnLinux \
    --exclude /home/mwerlen/Dropbox \
    --exclude /home/mwerlen/VirtualBox\ VMs/ \
    --exclude /home/mwerlen/.cache \
    --exclude /home/mwerlen/.npm \
    --exclude /home/mwerlen/.m2/repository/  \
    --exclude /home/mwerlen/Android/Sdk/extras/google/m2repository \
    --exclude /home/mwerlen/.local/share/Trash \
    --eclude /var/lib/docker/aufs \
    /* \
    "${USER}@localhost::${RSYNC_SHARE}/${DIRECTORY}"

FINISH=$(date +%s)
echo "Backup total time: $(( ($FINISH-$START) / 60 )) minutes, $(( ($FINISH-$START) % 60 )) seconds"

echo "Killing ssh tunnel"
ssh -S $CTRL_SOCKET -O exit $USER@$SERVER

echo "Done !"
