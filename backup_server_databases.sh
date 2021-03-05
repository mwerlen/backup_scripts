#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Inspired from https://wiki.postgresql.org/wiki/Automated_Backup_on_Linux

##############################
## POSTGRESQL BACKUP CONFIG ##
##############################

BACKUP_USER=root
USERNAME=postgres
BACKUP_DIR=/media/disk/saveMax/pg_dump/

# List of strings to match against database name, separated by space or comma.
# Any database names which contain any of these values will NOT be dumped.
DATABASE_EXCLUDE_LIST="root"

#### SETTINGS FOR ROTATED BACKUPS ####

# Which day to take the weekly backup from (1-7 = Monday-Sunday)
DAY_OF_WEEK_TO_KEEP=6

# Number of days to keep daily backups
DAYS_TO_KEEP=14

# How many weeks to keep weekly backups
WEEKS_TO_KEEP=5

# How many month to keep monthly backups
MONTHS_TO_KEEP=3

###########################
#### PRE-BACKUP CHECKS ####
###########################

# Make sure we're running as the required backup user
if [[ "${BACKUP_USER}" != "" && "$(id -un)" != "${BACKUP_USER}" ]]; then
    echo "This script must be run as ${BACKUP_USER}. Exiting." 1>&2
    exit 1
fi

# Make sure BACKUP_DIR is writable
if [[ ! -w "${BACKUP_DIR}" ]]; then
    echo "Destination directory ${BACKUP_DIR} is not writable by $(id -un)"
    exit 2
fi

###########################
#### START THE BACKUPS ####
###########################

function perform_backups()
{
    SUFFIX=$1
    FINAL_BACKUP_DIR="${BACKUP_DIR}$(date +\%Y-\%m-\%d)${SUFFIX}/"


    if ! mkdir -p ${FINAL_BACKUP_DIR}; then
        echo "Cannot create backup directory in ${FINAL_BACKUP_DIR}. Go and fix it!" 1>&2
        exit 1
    else
        echo "Making backup directory in ${FINAL_BACKUP_DIR}"
    fi

    ###########################
    ###### FULL BACKUPS #######
    ###########################
    
    EXCLUDE_DB_CLAUSE=""

    for DB_EXCLUDE in ${DATABASE_EXCLUDE_LIST//,/ }
    do
        EXCLUDE_DB_CLAUSE="${EXCLUDE_DB_CLAUSE} and datname !~ '${DB_EXCLUDE}'"
    done

    FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn ${EXCLUDE_DB_CLAUSE} order by datname;"

    for DATABASE in `psql -U "${USERNAME}" -At -c "${FULL_BACKUP_QUERY}" postgres`
    do
        echo "Backup of ${DATABASE}"

        if ! pg_dump -U "${USERNAME}" --format=plain  --compress=9 --file="${FINAL_BACKUP_DIR}${DATABASE}.sql.gz.in_progress" "${DATABASE}"; then
            echo "[!!ERROR!!] Failed to produce plain backup database ${DATABASE}" 1>&2
        else
            mv "${FINAL_BACKUP_DIR}${DATABASE}.sql.gz.in_progress" "${FINAL_BACKUP_DIR}${DATABASE}.sql.gz"
        fi

    done

    echo "All database backups complete!"
    touch "${BACKUP_DIR}latest_successful_backup"
}

# MONTHLY BACKUPS
DAY_OF_MONTH=`date +%d`

if [ ${DAY_OF_MONTH} -eq 1 ];
then
    perform_backups "-monthly"

    # Delete all expired monthly directories
    EXPIRED_DAYS=`expr $(((${MONTHS_TO_KEEP} * 31) + 1))`
    find ${BACKUP_DIR} -maxdepth 1 -mtime +${EXPIRED_DAYS} -name "*-monthly" -exec rm -rf '{}' ';'

    exit 0;
fi

# WEEKLY BACKUPS
DAY_OF_WEEK=`date +%u` #1-7 (Monday-Sunday)

if [ ${DAY_OF_WEEK} = ${DAY_OF_WEEK_TO_KEEP} ];
then
    perform_backups "-weekly"
    
    # Delete all expired weekly directories
    EXPIRED_DAYS=`expr $(((${WEEKS_TO_KEEP} * 7) + 1))`
    find ${BACKUP_DIR} -maxdepth 1 -mtime +${EXPIRED_DAYS} -name "*-weekly" -exec rm -rf '{}' ';'

    exit 0;
fi

# DAILY BACKUPS
perform_backups "-daily"

# Delete expired daily backups
find ${BACKUP_DIR} -maxdepth 1 -mtime +${DAYS_TO_KEEP} -name "*-daily" -exec rm -rf '{}' ';'
