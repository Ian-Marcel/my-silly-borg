#!/usr/bin/env bash

# Tells where the script is located
SHPWD=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# check if .env file exists
if [ -e "$SHPWD/.env" -a -f "$SHPWD/.env" ]; then
    source "$SHPWD/.env"
fi
BKP_USER=${BACKUP_USER:-'backup'}             # user that will orchestrate the backup
BKP_DSTN=${BACKUP_DESTINATION:-'/mnt/backup'} # where the backup will be stored
BKP_ITMS=()                                   # items that will be archived
