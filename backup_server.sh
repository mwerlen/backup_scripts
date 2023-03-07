#!/bin/bash
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
BACKUP_GLOBAL_FOLDER=/media/disk/saveMax/server_backup
SOURCE=/
BACKUP_NAME=backup_on_
DRY_RUN=0
SEND_MAIL=0
DD_BACKUP=0
ROOT_RSYNC_BACKUP=0
SD_RSYNC_BACKUP=0
KODI_BACKUP=0
MAIL=root@server.werlen.fr

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
    echo "      -d          Backup root system with DD"
    echo "      -r          Backup root system with rsync"
    echo "      -s          Backup SD card with rsync"
    echo "      -k          Backup kodi"
    echo "      -n <number> Keep <number> backups (default: 5)"
}


#####################################################
#                                                   #
# Options processing                                #
#                                                   #
#####################################################
while getopts ":htm:drskn:" opt; do
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
        d)
            DD_BACKUP=1
            ;;
        r)
            ROOT_RSYNC_BACKUP=1
            ;;
        s)
            SD_RSYNC_BACKUP=1
            ;;
        k)
            KODI_BACKUP=1
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


#####################################################
#                                                   #
# Some verifications                                #
#                                                   #
#####################################################
if [[ $EUID -ne 0 ]]; then
    echo "You must be root to launch backup script" 2>&1
    exit 1
fi
if [ ! -d "$BACKUP_GLOBAL_FOLDER" ]; then
    echo "Backup folder ($BACKUP_GLOBAL_FOLDER) is not accessible"
    exit 2
fi

#####################################################
#                                                   #
# Operation summary                                 #
#                                                   #
#####################################################
[ $DRY_RUN = 1 ] && echo "Operation scheduled in dry-run (no-op):" || echo "Operations scheduled:"
[ $DD_BACKUP = 1 ] && echo " - Root FS backup with DD"
[ $ROOT_RSYNC_BACKUP = 1 ] && echo " - Root FS backup with rsync"
[ $SD_RSYNC_BACKUP = 1 ] && echo " - SD backup with rsync"
[ $KODI_BACKUP = 1 ] && echo " - Kodi backups sync"
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
while [ -d $CURRENT_FOLDER ]; do
    COUNTER=${COUNTER-2};
    CURRENT_FOLDER=$BACKUP_GLOBAL_FOLDER/$BACKUP_NAME$CURRENT_DATE-${COUNTER};
    ((COUNTER++));
done
if [ $DRY_RUN = 1 ]; then
    echo "Would create a new backup folder : $CURRENT_FOLDER"
else
    echo "Creating a new backup folder : $CURRENT_FOLDER"
    mkdir $CURRENT_FOLDER
    touch "$CURRENT_FOLDER/XX-Backup from $(date '+%A, %d %B %Y, %T')"
fi

#####################################################
#                                                   #
# Backups                                           #
#                                                   #
#####################################################
GLOBAL_START=$(date +%s)

###########
# DD Backup
###########
if [ $DD_BACKUP = 1 ]; then
    START=$(date +%s)
    echo "--------------------------------"
    echo "-> Server backup with dd..."
    
    DD_FOLDER=$CURRENT_FOLDER/server_dd
    DD_COMMAND="dd if=/dev/sda of=${DD_FOLDER}/home_server_sda.img bs=1024"

    if [ $DRY_RUN = 1 ]; then
        echo "Would run \"$DD_COMMAND\""
    else
        mkdir $DD_FOLDER
        eval "$DD_COMMAND";
    fi

    FINISH=$(date +%s)
    echo "DD backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s"
fi

############
# ROOT Rsync
############
if [ $ROOT_RSYNC_BACKUP = 1 ]; then
    START=$(date +%s)
    echo "--------------------------------"
    echo "-> Server backup with rsync..."
    
    ROOT_RSYNC_FOLDER=$CURRENT_FOLDER/server
    ROOT_RSYNC_COMMAND="rsync --quiet --archive --acls --xattrs --verbose /* ${ROOT_RSYNC_FOLDER} --exclude /dev/ --exclude /proc/ --exclude /sys/ --exclude /tmp/ --exclude /run/ --exclude /mnt/ --exclude /media/ --exclude /var/run/ --exclude /var/lock/ --exclude /var/tmp/ --exclude /var/lib/urandom/ --exclude /lost+found --exclude /var/lib/lxcfs/cgroup --exclude /var/lib/lxcfs/proc"

    if [ $DRY_RUN = 1 ]; then
        echo "Would run \"$ROOT_RSYNC_COMMAND\"";
    else
        mkdir $ROOT_RSYNC_FOLDER
        eval "$ROOT_RSYNC_COMMAND";
    fi
    
    FINISH=$(date +%s)
    echo "Root backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s"
fi

##########
# SD Rsync
##########
if [ $SD_RSYNC_BACKUP = 1 ]; then
    START=$(date +%s)
    echo "--------------------------------"
    echo "-> SD backup with rsync..."

    SD_RSYNC_FOLDER=$CURRENT_FOLDER/sd
    SD_RSYNC_COMMAND="rsync --quiet --archive --acls --xattrs --verbose /mnt/sd ${SD_RSYNC_FOLDER} --exclude /lost+found"

    if [ $DRY_RUN = 1 ]; then
        echo "Would run \"$SD_RSYNC_COMMAND\""
    else
        mkdir $SD_RSYNC_FOLDER
        eval "$SD_RSYNC_COMMAND";
    fi
   
    FINISH=$(date +%s)
    echo "SD backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s"
fi

#############
# Kodi Backup
#############

if [ $KODI_BACKUP = 1 ]; then
    START=$(date +%s)
    echo "--------------------------------"
    echo "-> Kodi backup"

    KODI_FOLDER=$CURRENT_FOLDER/kodi_backup
    KODI_CP_COMMAND="mv /home/kodi/backups/* ${KODI_FOLDER}"

    if [ $DRY_RUN = 1 ]; then
        echo "Would run \"$KODI_CP_COMMAND\""
    else
        mkdir $KODI_FOLDER
        eval "$KODI_CP_COMMAND";
    fi

    FINISH=$(date +%s)
    echo "Kodi backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s"
fi

# Final Log
GLOBAL_FINISH=$(date +%s)
echo ""
echo ""
echo "Total backup time: $(( ($GLOBAL_FINISH-$GLOBAL_START)/3600 ))h $(( (($GLOBAL_FINISH-$GLOBAL_START)/60)%60 ))m $(( ($GLOBAL_FINISH-$GLOBAL_START)%60 ))s"

#####################################################
#                                                   #
# Mail                                              #
#                                                   #
#####################################################
if [ $SEND_MAIL = 1 ]; then
    if [ $DRY_RUN = 1 ]; then
        echo "Would send mail to $MAIL"
    else
        echo "Sending mail to $MAIL"
        echo "Total backup time: $(( ($GLOBAL_FINISH-$GLOBAL_START)/3600 ))h $(( (($GLOBAL_FINISH-$GLOBAL_START)/60)%60 ))m $(( ($GLOBAL_FINISH-$GLOBAL_START)%60 ))s" | mail -s "Server backup" $MAIL
    fi
fi

#####################################################
#                                                   #
# Rotation                                          #
#                                                   #
#####################################################

if [ $DRY_RUN = 1 ]; then
    echo "Would remove old backup"
else
    echo "Removing old backups"
    \ls -1Ad $BACKUP_GLOBAL_FOLDER/$BACKUP_NAME* | sort -r | tail -n +$(expr $RETENTION_NUMBER + 1) | xargs -I dirs rm -r dirs
fi

