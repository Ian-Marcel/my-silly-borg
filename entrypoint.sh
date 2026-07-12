#!/usr/bin/env bash

# Abort on any error (-e), unset variable reference (-u), or pipe failure (-o pipefail).
# set -euo pipefail
# On any error, print the script name, line number, failing command, and exit code to stderr.
# trap 'echo -e "[ FATAL ] Error in ${BASH_SOURCE[0]} at line ${LINENO}: ${BASH_COMMAND} \n\n[ EXIT ${?} ]" >&2' ERR

# Resolve the absolute path of the directory containing this script,
# regardless of where it is invoked from.
SHPWD=$(realpath "$0")
SHPWD=$(dirname "$SHPWD")

# Load configuration overrides from .env if present alongside this script.
if [ -f "$SHPWD/.env" ]; then
    source "$SHPWD/.env"
fi

# ── Backup configuration ──────────────────────────────────────────────────────
# Bash’s printf has a built-in method of getting the date which can be used in
# place of the date command.
date() {
    # Usage: date "format"
    # See: 'man strftime' for format.
    printf "%($1)T\\n" "-1"
}
BKP_USER=${BACKUP_USER:-'backup'}                     # user that will orchestrate the backups
BKP_DSTN=${BACKUP_DESTINATION:-'/mnt/my-silly-borg'}  # where the backup will be stored
BKP_LOG_DSTN=${BACKUP_LOG_DESTINATION:-"$SHPWD/logs"} # where the backup's logs will be stored
ARCHV_NM=$(hostname)_$(date %Y-%m-%dT%H:%M:%S)
LOG_FILE="${BKP_LOG_DSTN}/${ARCHV_NM}.log"
BKP_PASSWD=${BACKUP_PASSWORD:-'VvlNeR4bL3_-_r3P0'} # backup password
if [ -n "$BACKUP_ITEMS" ]; then
    IFS=';'
    read -ra BKP_ITMS <<<"${BACKUP_ITEMS}"
else
    BKP_ITMS=("/home")
fi

case "${1:-}" in
--quiet | -q)
    # Quiet mode: save to log file only (no live output)
    exec &>"${LOG_FILE}"
    echo "Running in quiet mode (output saved to ${LOG_FILE})"
    ;;
*)
    # Normal mode: show live output AND save to log file
    exec &> >(tee "${LOG_FILE}")
    echo "Running in normal mode (live output + saved to ${LOG_FILE})"
    ;;
esac

if ! command -v borg >/dev/null 2>&1; then
    echo -e "[ WARN ] borgbackup wasn't found, attempting to install it."
    sudo apt update >/dev/null 2>&1 && sudo apt install -y borgbackup >/dev/null 2>&1 ||
        sudo dnf install -y --quiet borgbackup >/dev/null 2>&1 ||
        sudo pacman -Sy --noconfirm --quiet borgbackup >/dev/null 2>&1
    if [ $? -gt 1 ]; then
        echo -e "[ FATAL ] Failed to install borgbackup. \n\n[ EXIT ]"
        exit 2
    fi

fi

if [ -f "$SHPWD/.env" ]; then
    echo -e "[ INFO ] .env file found, switching default values to .env's values."
    # Check if permissions are 600 or stricter (smaller octal value)
    PERMS=$(stat -c '%a' "$SHPWD/.env" 2>/dev/null || stat -f '%A' "$SHPWD/.env" 2>/dev/null)
    if [ "$PERMS" -gt 600 ]; then
        echo -e "[ FATAL ] .env file permissions are $PERMS, which is too loose (max allowed: 600). \n\n[ EXIT 1 ]"
        exit 1
    fi
fi

# ── Borg environment variables ────────────────────────────────────────────────
export BORG_REPO="$BKP_DSTN"                          # path Borg treats as the repository root
export BORG_PASSPHRASE="$BKP_PASSWD"                  # passphrase used to unlock repository encryption
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes # suppress the prompt when no encryption marker is found
export BORG_CHECK_I_KNOW_WHAT_I_AM_DOING=NO           # guard against accidental destructive Borg operations

# ── Pre-flight checks ─────────────────────────────────────────────────────────
if ! command -v borg >/dev/null 2>&1; then
    echo -e "[ FATAL ] borgbackup's command \`borg\` was not found! Install it. \n\n[ EXIT ]"
    exit 1
fi

# Ensure the designated backup user exist.
if ! id "$BKP_USER" >/dev/null 2>&1; then
    echo -e "[ FATAL ] User $BKP_USER does not exist. \n\n[ EXIT ]"
    exit 1
fi
# Ensure the script is running as the designated backup user.
if [ "$(whoami)" != "$BKP_USER" ]; then
    echo -e "[ FATAL ] Not $BKP_USER! \n\n[ EXIT ]"
    exit 1
fi

# Ensure the backup destination and log storage directories both exist.
# If either is absent, walk up the directory tree to verify write access
# before attempting to create them.
if ! [ -d "$BKP_DSTN" ] || ! [ -d "$BKP_LOG_DSTN" ]; then
    BKP_DSTN_BASE=$(dirname "$BKP_DSTN")
    BKP_LOG_BASE=$(dirname "$BKP_LOG_DSTN")

    # Parent directories are also absent — check one level higher for write access.
    if ! [ -d "$BKP_DSTN_BASE" -o -d "$BKP_LOG_BASE" ]; then
        echo -e "[ WARN ] The base of the backup's directories are non-existant! \nChecking if they're writable by $BKP_USER..."
        if ! [ -w "$(dirname "$BKP_DSTN_BASE")" ] || ! [ -w "$(dirname "$BKP_LOG_BASE")" ]; then
            echo -e "[ FATAL ] Either backup's: \n  - Destination directory \n  - Log directory \n  - Both \nCoundn't be created. \n\n[ EXIT ]"
            exit 1
        fi
    # Parent directories exist but the backup user lacks write permission.
    elif ! [ -w "$BKP_DSTN_BASE" ] || ! [ -w "$BKP_LOG_BASE" ]; then
        echo -e "[ FATAL ] The base of the backup's directories exists, yet:"
        echo -e "Either backup's: \n  - Destination directory \n  - Log directory \n  - Both \nCoundn't be created. \n\n[ EXIT ]"
        exit 1
    fi

    # Write access confirmed — create any missing directories.
    echo -e "[ INFO ] Either backup's: \n  - Destination directory \n  - Log directory \n  - Both \nNot found. \nCreating..."
    mkdir -p "$BKP_DSTN" "$BKP_LOG_DSTN"
fi

# Initialize a new Borg repository if no config file is found at the repo path.
if [ ! -f "$BORG_REPO/config" ]; then
    echo "[ INFO ] Initializing Borg repository at $BORG_REPO"
    borg init -e repokey "$BORG_REPO"
    if [ $? -ne 0 ]; then
        echo -e "[ FATAL ] Failed to initialize Borg repository \n\n[ EXIT ]" >&2
        exit 1
    fi
fi

# Initialize the backup
echo -e "[ INFO ] Starting backup\n"
# Backup the most important directories into an archive named after
# the machine this script is currently running on:

sudo -E borg create \
    --filter AME \
    --list \
    --stats \
    --show-rc \
    --compression zstd \
    --exclude-caches \
    --exclude '*/.cache/*' \
    --exclude '*/cache/*' \
    --exclude '*/tmp/*' \
    ::"$ARCHV_NM" \
    ${BKP_ITMS[@]}

backup_exit=$?

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}_*' matching is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

echo -e "\n[ INFO ] Pruning repository\n"

sudo -E borg prune \
    --verbose \
    --list \
    --glob-archives '{hostname}_*' \
    --show-rc \
    --keep-hourly ${KEEP_HOURLY:-0} \
    --keep-daily ${KEEP_DAILY:-7} \
    --keep-weekly ${KEEP_WEEKLY:-4} \
    --keep-monthly ${KEEP_MONTHLY:-6}

prune_exit=$?

# actually free repo disk space by compacting segments

echo -e "\n[ INFO ] Compacting repository\n"

sudo -E borg compact --verbose

compact_exit=$?

echo -e "\n[ INFO ] Removing old logs"

mapfile -t ALL_BACKUPS < <(sudo -E borg list --short)
DELED_LOGS=0
for file in "${BKP_LOG_DSTN}"/*.log; do
    if [[ ! ${ALL_BACKUPS[*]} =~ $(basename "${file}" | sed 's/.log//g') ]]; then
        rm --verbose "${file}"
        DELED_LOGS=$((DELED_LOGS + 1))
    fi
done
if [ $DELED_LOGS -eq 0 ]; then
    echo "[ INFO ] No logs removed"
fi

# use highest exit code as global exit code
global_exit=$((backup_exit > prune_exit ? backup_exit : prune_exit))
global_exit=$((compact_exit > global_exit ? compact_exit : global_exit))

echo " "
if [ ${global_exit} -eq 0 ]; then
    echo -e "[ INFO ] Backup, Prune, and Compact finished successfully"
elif [ ${global_exit} -eq 1 ]; then
    echo -e "[ WARN ] Backup, Prune, and/or Compact finished with warnings"
else
    echo -e "[ FATAL ] Backup, Prune, and/or Compact finished with errors \n\n[ EXIT ]"
fi

exit ${global_exit}
