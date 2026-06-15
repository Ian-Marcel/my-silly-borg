#!/usr/bin/env bash

set -euo pipefail
# Tells where the script is located
SHPWD=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# check if .env file exists, main values can be edited here in the variables before the Borg-specific ones, but through .env is preferable
if [ -e "$SHPWD/.env" -a -f "$SHPWD/.env" ]; then
    source "$SHPWD/.env"
fi
BKP_USER=${BACKUP_USER:-'backup'}                    # user that will orchestrate the backups
BKP_DSTN=${BACKUP_DESTINATION:-'/mnt/backup/data'}   # where the backup will be stored
BKP_LOG_STG=${BACKUP_LOG_STORAGE:-'/mnt/backup/log'} # where the backup's logs will be stored
BKP_PASSWD=${BACKUP_PASSWORD:-'VvlNeR4bL3_-_r3P0'}   # backup password
BKP_ITMS=()                                          # items that will be archived

# Borg-specific variables
export BORG_REPO="$BKP_DSTN"
export BORG_PASSPHRASE="$BKP_PASSWD"
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
export BORG_CHECK_I_KNOW_WHAT_I_AM_DOING=NO

# Check if the right user is being used
if [ "$(whoami)" != "$BKP_USER" ]; then
    echo -e "Not $BKP_USER! \nExiting..."
    exit 1
fi

# Check if the folders exists
if ! [ -d "$BKP_DSTN" ] || ! [ -d "$BKP_LOG_STG" ]; then
    BKP_DSTN_BASE=$(dirname "$BKP_DSTN")
    BKP_LOG_BASE=$(dirname "$BKP_LOG_STG")
    if ! [ -d "$BKP_DSTN_BASE" -o -d "$BKP_LOG_BASE" ]; then
        echo -e "The base of the backup's directories are non-existant! \nChecking if they're writable by $BKP_USER..."
        if ! [ -w "$(dirname "$BKP_DSTN_BASE")" ] || ! [ -w "$(dirname "$BKP_LOG_BASE")" ]; then
            echo -e "Either backup's: \n  - Destination directory \n  - Log directory \n  - Both \nCoundn't be created. \n\n[ EXIT ]"
            exit 1
        fi
    elif ! [ -w "$BKP_DSTN_BASE" ] || ! [ -w "$BKP_LOG_BASE" ]; then
        echo -e "The base of the backup's directories exists, yet:"
        echo -e "Either backup's: \n  - Destination directory \n  - Log directory \n  - Both \nCoundn't be created. \n\n[ EXIT ]"
        exit 1
    fi
    # Creates "$BKP_DSTN" "$BKP_LOG_STG" if not found
    echo -e "Either backup's: \n  - Destination directory \n  - Log directory \n  - Both \nNot found. \nCreating..."
    mkdir -p "$BKP_DSTN" "$BKP_LOG_STG"
fi

# Initialize Borg repository if it doesn't exist
if [ ! -f "$BORG_REPO/config" ]; then
    echo "Initializing Borg repository at $BORG_REPO"
    borg init -e repokey "$BORG_REPO"
    if [ $? -ne 0 ]; then
        echo "Failed to initialize Borg repository" >&2
        exit 1
    fi
fi
