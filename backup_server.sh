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
FLICKR_BACKUP=0
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
    echo "      -f          Backup pictures on FlickR"
    echo "      -n <number> Keep <number> backups (default: 5)"
}


#####################################################
#                                                   #
# Options processing                                #
#                                                   #
#####################################################
while getopts ":htm:drsfn:" opt; do
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
        f)
            FLICKR_BACKUP=1
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
# Logging                                           #
#                                                   #
#####################################################
LOGFILE=""
TEMPLOG=""
log() {
    LOG="$1"
    if [ -z "$LOGFILE" ]; then
        TEMPLOG+="${LOG}\n"
        echo "$LOG"
    else
        if [ ! -z "$TEMPLOG" ]; then
            echo -e "${TEMPLOG: : -1}" >> $LOGFILE
            TEMPLOG=""
        fi
        echo "$LOG" | tee -a "$LOGFILE"
    fi
}


runCommand() {
    COMMAND=$1
    FOLDER=$2
    if [ $DRY_RUN = 1 ]; then
        log "Would run \"$COMMAND\" in \"$FOLDER\""
    else
        mkdir $FOLDER
        RETURN=""
        set +e
        eval "$COMMAND" 2>&1 | tee $LOGFILE;
        set -e
        RETURN=$?
        if [ $RETURN -eq 0 ]
        then
            log "Backup command successfully completed"
        else
            log "Backup command ended with error code $RETURN"
        fi
    fi

    
}

#####################################################
#                                                   #
# Operation summary                                 #
#                                                   #
#####################################################
[ $DRY_RUN = 1 ] && log "Operation scheduled in dry-run (no-op):" || log "Operations scheduled:"
[ $DD_BACKUP = 1 ] && log " - Root FS backup with DD"
[ $ROOT_RSYNC_BACKUP = 1 ] && log " - Root FS backup with rsync"
[ $SD_RSYNC_BACKUP = 1 ] && log " - SD backup with rsync"
[ $FLICKR_BACKUP = 1 ] && log " - Pictures backup on flickR"
[ $SEND_MAIL = 1 ] && log " - Sending mail at the end to $MAIL"
log " - Cleaning up backup to keep at most $RETENTION_NUMBER backups"
log ""

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
LOGFILELOCATION="$CURRENT_FOLDER/backup.log"
if [ $DRY_RUN = 1 ]; then
    log "Would create a new backup folder : $CURRENT_FOLDER"
    log "Would create a new log file : $LOGFILELOCATION"
else
    log "Creating a new backup folder : $CURRENT_FOLDER"
    mkdir $CURRENT_FOLDER
    touch "$CURRENT_FOLDER/XX-Backup from $(date '+%A, %d %B %Y, %T')"
    LOGFILE="$LOGFILELOCATION"
    log "Creating a new log file : $LOGFILELOCATION"
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
    log ""
    log "--------------------------------"
    log "-> Server backup with dd..."
    
    DD_FOLDER=$CURRENT_FOLDER/server_dd
    DD_COMMAND="ddrescue --quiet /dev/sda ${DD_FOLDER}/home_server_sda.img ${DD_FOLDER}/home_server_sda.log"

    runCommand "$DD_COMMAND" "$DD_FOLDER"

    FINISH=$(date +%s)
    log "DD backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s"
fi

############
# ROOT Rsync
############
if [ $ROOT_RSYNC_BACKUP = 1 ]; then
    START=$(date +%s)
    log ""
    log "--------------------------------"
    log "-> Server backup with rsync..."
    
    ROOT_RSYNC_FOLDER=$CURRENT_FOLDER/server
    ROOT_RSYNC_COMMAND="rsync --quiet --archive --acls --xattrs --ignore-errors --verbose /* ${ROOT_RSYNC_FOLDER} --exclude /dev/ --exclude /proc/ --exclude /sys/ --exclude /tmp/ --exclude /run/ --exclude /mnt/ --exclude /media/ --exclude /var/run/ --exclude /var/lock/ --exclude /var/tmp/ --exclude /var/lib/urandom/ --exclude /lost+found"

    runCommand "$ROOT_RSYNC_COMMAND" "$ROOT_RSYNC_FOLDER"

    FINISH=$(date +%s)
    log "Root backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s"
fi

##########
# SD Rsync
##########
if [ $SD_RSYNC_BACKUP = 1 ]; then
    START=$(date +%s)
    log ""
    log "--------------------------------"
    log "-> SD backup with rsync..."

    SD_RSYNC_FOLDER=$CURRENT_FOLDER/sd
    SD_RSYNC_COMMAND="rsync --quiet --archive --acls --xattrs --verbose /mnt/sd ${SD_RSYNC_FOLDER} --exclude /lost+found"

    runCommand "$SD_RSYNC_COMMAND" "$SD_RSYNC_FOLDER";

    FINISH=$(date +%s)
    log "SD backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s"
fi

##############
# Flick Backup
##############

if [ $FLICKR_BACKUP = 1 ]; then
    START=$(date +%s) 
    log ""
    log "--------------------------------"
    log "-> FlickR backup"

    if [ $DRY_RUN = 1 ]; then
        log "Would run long flickrUpload script..."
        FINISH=$(date +%s)
    else
        cd /usr/local/src/flickr_uploadr/
        # reset log
        echo "Lancement par le script backup_server.sh" > /var/log/uploadr.log
        set +e
        python -u /usr/local/src/flickr_uploadr/uploadr.py 2>&1 | tee $LOGFILE
        set -e
        FINISH=$(date +%s)
    fi
   
    log "Flickr backup total time: $(( ($FINISH-$START)/3600 ))h $(( (($FINISH-$START)/60)%60 ))m $(( ($FINISH-$START)%60 ))s" | tee -a /var/log/uploadr.log
fi


# Final Log
GLOBAL_FINISH=$(date +%s)
log ""
log ""
log "Total backup time: $(( ($GLOBAL_FINISH-$GLOBAL_START)/3600 ))h $(( (($GLOBAL_FINISH-$GLOBAL_START)/60)%60 ))m $(( ($GLOBAL_FINISH-$GLOBAL_START)%60 ))s"

#####################################################
#                                                   #
# Mail                                              #
#                                                   #
#####################################################
if [ $SEND_MAIL = 1 ]; then
    if [ $DRY_RUN = 1 ]; then
        log "Would send mail to $MAIL"
    else
        log "Sending mail to $MAIL"
        echo "Total backup time: $(( ($GLOBAL_FINISH-$GLOBAL_START)/3600 ))h $(( (($GLOBAL_FINISH-$GLOBAL_START)/60)%60 ))m $(( ($GLOBAL_FINISH-$GLOBAL_START)%60 ))s" | mail -s "Server backup" -a $LOGFILE $MAIL
    fi
fi

#####################################################
#                                                   #
# Rotation                                          #
#                                                   #
#####################################################

if [ $DRY_RUN = 1 ]; then
    log "Would remove old backup"
else
    log "Removing old backups"
    \ls -1Ad $BACKUP_GLOBAL_FOLDER/$BACKUP_NAME* | sort -r | tail -n +$(expr $RETENTION_NUMBER + 1) | xargs -I dirs rm -r dirs
fi

