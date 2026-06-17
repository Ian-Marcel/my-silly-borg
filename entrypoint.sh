#!/usr/bin/env bash

# Abort on any error (-e), unset variable reference (-u), or pipe failure (-o pipefail).
set -euo pipefail
# On any error, print the script name, line number, failing command, and exit code to stderr.
trap 'echo -e "[ FATAL ] Error in ${BASH_SOURCE[0]} at line ${LINENO}: ${BASH_COMMAND} \n\n[ EXIT ${?} ]" >&2' ERR

# Resolve the absolute path of the directory containing this script,
# regardless of where it is invoked from.
SHPWD=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)

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
BKP_USER=${BACKUP_USER:-'backup'}                                # user that will orchestrate the backups
BKP_DSTN=${BACKUP_DESTINATION:-'/mnt/my-silly-borg'}             # where the backup will be stored
BKP_LOG_DSTN=${BACKUP_LOG_DESTINATION:-'/var/log/my-silly-borg'} # where the backup's logs will be stored
ARCHV_NM=${ARCHIVE_NAME:-$(hostname)_$(date %Y-%m-%dT%H:%M:%S)}
LOG_FILE="${BKP_LOG_DSTN}/${ARCHV_NM}.log"
BKP_PASSWD=${BACKUP_PASSWORD:-'VvlNeR4bL3_-_r3P0'} # backup password
if [ -n "$BACKUP_ITEMS" ]; then
    IFS=';'
    read -ra BKP_ITMS <<<"${BACKUP_ITEMS}"
else
    BKP_ITMS=("/home")
fi

exec &> >(tee "${LOG_FILE}")

if [ -f "$SHPWD/.env" ]; then
    echo -e "[ INFO ] .env file found, switching default values to .env's values."
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
    --exclude '*/tmp/*' \
    --noatime \
    ::"$ARCHV_NM" \
    ${BKP_ITMS[@]}

backup_exit=$?

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}-*' matching is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

echo -e "\n[ INFO ] Pruning repository\n"

sudo -E borg prune \
    --list \
    --glob-archives '{hostname}-*' \
    --show-rc \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6

prune_exit=$?

# actually free repo disk space by compacting segments

echo -e "\n[ INFO ] Compacting repository\n"

sudo -E borg compact --verbose

compact_exit=$?

echo -e "\n[ INFO ] Removing old logs\n"

mapfile -t ALL_BACKUPS < <(sudo -E borg list --short)
for file in "${BKP_LOG_DSTN}"/*.log; do
    if [[ ! ${ALL_BACKUPS[*]} =~ $(basename "${file}" | sed 's/.log//g') ]]; then
        rm --verbose "${file}"
    fi
done

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
