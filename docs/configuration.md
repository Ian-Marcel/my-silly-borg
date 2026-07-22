# Configuration

All settings live in a file called `.env`, placed in the same folder as
`entrypoint.sh`. If a setting is missing from `.env`, the script uses its
built-in default instead.

## All the settings

| Variable | Default | What it does |
|---|---|---|
| `BACKUP_USER` | `backup` | The user that must run the script |
| `BACKUP_DESTINATION` | `/mnt/my-silly-borg` | Where the backup repository lives |
| `BACKUP_LOG_DESTINATION` | `<folder containing entrypoint.sh>/logs` | Where log files are saved |
| `BACKUP_PASSWORD` | *(a placeholder — see below)* | The password that locks your backup |
| `BACKUP_ITEMS` | `/home` | The folders you want backed up |
| `NOT_THESE_ITEMS` | `*/.cache/*;*/cache/*;*/tmp/*` | The folders you want skipped |
| `BACKUP_COMPRESSION_METHOD` | `zstd` | How the backup data gets compressed |
| `KEEP_HOURLY` | `0` | How many hourly backups to keep |
| `KEEP_DAILY` | `7` | How many daily backups to keep |
| `KEEP_WEEKLY` | `4` | How many weekly backups to keep |
| `KEEP_MONTHLY` | `6` | How many monthly backups to keep |

> [!note]
> An older version of this doc listed the wrong default folder
> (`/mnt/backup/data`) and the wrong variable name for the logs folder
> (`BACKUP_LOG_STORAGE`). The table above matches what's actually in
> `entrypoint.sh`.

## `BACKUP_PASSWORD` — change this!

The script comes with a placeholder password built in. **Always set your own**
in `.env`. If you don't, anyone who can read the script can unlock your
backup.

## `BACKUP_ITEMS` — what to back up

List the folders you want backed up, separated by `;`:

```sh
BACKUP_ITEMS='/home;/var/spaced dir;/etc'
```

Folder names with spaces are fine. Folder names with a `;` in them are **not**
fine — the script will treat the `;` as a separator and split that one folder
into two, breaking the backup. Avoid `;` in folder names.

If you don't set this, the script backs up `/home`.

## `NOT_THESE_ITEMS` — what to skip

List patterns to skip, also separated by `;`:

```sh
NOT_THESE_ITEMS='*/.cache/*;*/cache/*;*/tmp/*;*/node_modules/*'
```

One thing to know: Borg's patterns work a little differently than you might
expect. To skip a folder no matter how deep it is, start the pattern with
`*/`, like `*/.cache/*` — not just `.cache/*`.

If you don't set this, the script skips cache and temp folders by default.

## `BACKUP_COMPRESSION_METHOD` — how tightly to squeeze your data

This picks which compression method Borg uses when storing your files. Some
squeeze harder (smaller backup, but slower), some squeeze less but run
faster. Your options:

| Value | Speed | How much smaller | Notes |
|---|---|---|---|
| `none` | Fastest | None | No compression at all |
| `lz4` | Very fast | Small | Good if speed matters more than size |
| `zstd` | Fast | Good | A solid, balanced default — **this is what the script uses if you don't set anything** |
| `zlib` | Medium | Medium | Also known as "gzip" |
| `lzma` | Slow | Best | Best for shrinking size, but much slower |

You can also fine-tune some of these with a level, e.g. `zstd,10` (zstd
supports levels 1–22) or `lzma,6` (lzma supports levels 0–9). If you're not
sure, the default (`zstd`) is a good choice.

```sh
BACKUP_COMPRESSION_METHOD='lzma,6'
```

## Example `.env` file

```sh
BACKUP_USER='backup'
BACKUP_DESTINATION='/mnt/backup/data'
BACKUP_LOG_DESTINATION='/mnt/backup/log'
BACKUP_PASSWORD='your-strong-passphrase-here'
BACKUP_ITEMS='/home;/etc;/var/lib/postgresql'
NOT_THESE_ITEMS='*/.cache/*;*/cache/*;*/tmp/*'
BACKUP_COMPRESSION_METHOD='zstd'
KEEP_HOURLY='0'
KEEP_DAILY='7'
KEEP_WEEKLY='4'
KEEP_MONTHLY='6'
```

## File permissions

The `.env` file must not be readable by anyone but the owner — permissions of
`600` or stricter. If it's looser than that, the script refuses to run.

```sh
chmod 600 .env
```

[← Back to README](../README.md)
