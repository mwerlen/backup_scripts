#!/bin/bash
# shellcheck disable=SC2004
# strict mode on
set -euo pipefail
IFS=$'\n\t'

#########################################################################
#   This script automates a full server backup with backup rotation     #
#   Configurations are:                                                 #
#       * Backup retention (number of backup kept)                      #
#       * Backup location                                               #
#       * Source location                                               #
#########################################################################
#   Author : Maxime Werlen                                              #
#########################################################################

#####################################################
#                                                   #
# Configurations                                    #
#                                                   #
#####################################################
RETENTION_NUMBER=5
INTERNAL_BACKUP_DISK_MOUNT_DIR="/mnt/internal_backup"
BACKUP_GLOBAL_FOLDER="${INTERNAL_BACKUP_DISK_MOUNT_DIR}/saveMax/server_backup"
BACKUP_NAME="backup_on_"
DRY_RUN=0
SEND_MAIL=0
COPY_SSD_TO_HDD=0
ROOT_RSYNC_BACKUP=0
MAIL="root@server.werlen.fr"

#####################################################
#                                                   #
# Usage                                             #
#                                                   #
#####################################################
usage() {
    echo "Backup server - Copyright (c) Maxime Werlen"
    echo "Usage: backup_server.sh"
    echo "      -h          View this help message"
    echo "      -t          Test run, no backup made"
    echo "      -m <mail>   Send mail to <mail> at the end"
    echo "      -c          Copy SSD media folder to internal HDD"
    echo "      -r          Backup root system with rsync"
    echo "      -n <number> Keep <number> backups (default: 5)"
}


#####################################################
#                                                   #
# Options processing                                #
#                                                   #
#####################################################
while getopts ":htm:crn:" opt; do
    case $opt in
        h)
            usage
            exit 0
            ;;
        t)
            DRY_RUN=1
            ;;
        m)
            SEND_MAIL=1
            MAIL="$OPTARG"
            ;;
        c)
            COPY_SSD_TO_HDD=1
            ;;
        r)
            ROOT_RSYNC_BACKUP=1
            ;;
        n)
            if [[ $OPTARG == +([0-9]) ]]; then
                RETENTION_NUMBER=$OPTARG
            else
                echo "Invalid retention number : $OPTARG" >&2
                usage
                exit 2
            fi
            ;;
        \?)
            echo "Invalid option -$OPTARG" >&2
            usage
            exit 2 
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            exit 2
            ;;
    esac
done

function mount_disk {
    echo "Montage du disque de sauvegarde interne"
    # d950c733-e582-40fb-930f-602f82c5d0e4 -> ../../sdb1 (le HDD interne)
    mount /dev/disk/by-uuid/d950c733-e582-40fb-930f-602f82c5d0e4 "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
}

function unmount_disk {
    echo "Démontage du disque de sauvegarde interne"
    umount "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
}

#####################################################
#                                                   #
# Some verifications                                #
#                                                   #
#####################################################
if [[ $EUID -ne 0 ]]; then
    echo "You must be root to launch backup script" 2>&1
    exit 1
fi
if [[ ! -d "${INTERNAL_BACKUP_DISK_MOUNT_DIR}" ]]; then
    echo "Mount point for internal backup disk is missing. Creating it"
    mkdir -p "${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
fi

# Montage du disque de sauvegarde interne
trap unmount_disk SIGINT
trap unmount_disk EXIT
mount_disk

if [ ! -d "${BACKUP_GLOBAL_FOLDER}" ]; then
    echo "Backup folder ($BACKUP_GLOBAL_FOLDER) is not accessible"
    exit 2
fi

#####################################################
#                                                   #
# Operation summary                                 #
#                                                   #
#####################################################
[ $DRY_RUN = 1 ] && echo "Operation scheduled in dry-run (no-op):" || echo "Operations scheduled:"
[ $ROOT_RSYNC_BACKUP = 1 ] && echo " - Root FS backup with rsync"
[ $SEND_MAIL = 1 ] && echo " - Sending mail at the end to $MAIL"
echo " - Cleaning up backup to kep at most $RETENTION_NUMBER backups"
echo ""



#####################################################
#                                                   #
# Folder creation                                   #
#                                                   #
#####################################################
CURRENT_DATE=$(date -Iminutes)
CURRENT_FOLDER=$BACKUP_GLOBAL_FOLDER/$BACKUP_NAME$CURRENT_DATE
while [ -d "${CURRENT_FOLDER}" ]; do
    COUNTER=${COUNTER-2};
    CURRENT_FOLDER="${BACKUP_GLOBAL_FOLDER}/${BACKUP_NAME}${CURRENT_DATE}-${COUNTER}";
    ((COUNTER++));
done
if [ "${DRY_RUN}" = 1 ]; then
    echo "Would create a new backup folder : ${CURRENT_FOLDER}"
else
    echo "Creating a new backup folder : ${CURRENT_FOLDER}"
    mkdir "${CURRENT_FOLDER}"
    touch "${CURRENT_FOLDER}/XX-Backup from $(date '+%A, %d %B %Y, %T')"
fi

#####################################################
#                                                   #
# Backups                                           #
#                                                   #
#####################################################
GLOBAL_START="$(date +%s)"

#######################################
# Copy SSH media folder to internal HDD
#######################################
if [ "${COPY_SSD_TO_HDD}" = 1 ]; then
    START="$(date +%s)"
    echo "--------------------------------"
    echo "-> Copy media folder from SSH to internal HDD with rsync..."

    SRC_RSYNC_FOLDER="/media/disk/"
    DEST_RSYNC_FOLDER="${INTERNAL_BACKUP_DISK_MOUNT_DIR}"
    COPY_RSYNC_COMMAND="/usr/local/bin/rsync-no-vanished \
        --recursive \
        --one-file-system \
        --links --hard-links \
        --perms --executability \
        --times --atimes --open-noatime \
        --group --owner \
        --acls --xattrs \
        --delete-before \
        --no-compress \
        --quiet \
        --exclude 'saveMax/server_backup' \
        --exclude 'lost+found' \
        ${SRC_RSYNC_FOLDER} \
        ${DEST_RSYNC_FOLDER}"

    if [ "${DRY_RUN}" = 1 ]; then
        echo "Would run \"${COPY_RSYNC_COMMAND}\""
    else
        eval "${COPY_RSYNC_COMMAND}";
    fi
   
    FINISH="$(date +%s)"
    echo "SD backup total time: $(( (${FINISH}-${START})/3600 ))h $(( ((${FINISH}-${START})/60)%60 ))m $(( (${FINISH}-${START})%60 ))s"
fi

############
# ROOT Rsync
############
if [ "${ROOT_RSYNC_BACKUP}" = 1 ]; then
    START="$(date +%s)"
    echo "--------------------------------"
    echo "-> Server backup with rsync..."
    
    ROOT_RSYNC_FOLDER="${CURRENT_FOLDER}/server"
    ROOT_RSYNC_COMMAND="/usr/local/bin/rsync-no-vanished --quiet --archive --acls --xattrs --verbose /* ${ROOT_RSYNC_FOLDER} --exclude /dev/ --exclude /proc/ --exclude /sys/ --exclude /tmp/ --exclude /run/ --exclude /mnt/ --exclude /media/ --exclude /var/run/ --exclude /var/lock/ --exclude /var/tmp/ --exclude /var/lib/urandom/ --exclude /lost+found --exclude /var/lib/lxcfs/cgroup --exclude /var/lib/lxcfs/proc"

    if [ "${DRY_RUN}" = 1 ]; then
        echo "Would run \"${ROOT_RSYNC_COMMAND}\"";
    else
        mkdir "${ROOT_RSYNC_FOLDER}"
        eval "${ROOT_RSYNC_COMMAND}";
    fi
    
    FINISH="$(date +%s)"
    echo "Root backup total time: $(( (${FINISH}-${START})/3600 ))h $(( ((${FINISH}-${START})/60)%60 ))m $(( (${FINISH}-${START})%60 ))s"
fi

# Final Log
GLOBAL_FINISH="$(date +%s)"
echo ""
echo ""
echo "Total backup time: $(( ($GLOBAL_FINISH-$GLOBAL_START)/3600 ))h $(( (($GLOBAL_FINISH-$GLOBAL_START)/60)%60 ))m $(( ($GLOBAL_FINISH-$GLOBAL_START)%60 ))s"

#####################################################
#                                                   #
# Mail                                              #
#                                                   #
#####################################################
if [ "${SEND_MAIL}" = 1 ]; then
    if [ "${DRY_RUN}" = 1 ]; then
        echo "Would send mail to ${MAIL}"
    else
        echo "Sending mail to ${MAIL}"
        echo "Total backup time: $(( (${GLOBAL_FINISH}-${GLOBAL_START})/3600 ))h $(( ((${GLOBAL_FINISH}-${GLOBAL_START})/60)%60 ))m $(( (${GLOBAL_FINISH}-${GLOBAL_START})%60 ))s" | mail -s "Server backup" "${MAIL}"
    fi
fi

#####################################################
#                                                   #
# Rotation                                          #
#                                                   #
#####################################################

if [ "${DRY_RUN}" = 1 ]; then
    echo "Would remove old backup"
else
    echo "Removing old backups"
    find "${BACKUP_GLOBAL_FOLDER}" -maxdepth 1 -name "${BACKUP_NAME}"'*' | sort -r | tail -n +$(( "${RETENTION_NUMBER}" + 1)) | xargs -I dirs rm -r dirs
fi

