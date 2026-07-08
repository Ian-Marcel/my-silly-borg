# my-silly-borg

Entrypoint for the **my-silly-borg** portable BorgBackup orchestration script. Validates
the runtime environment, ensures required directories exist, and initializes the
Borg repository if not already present. Intended to run as the designated backup
user (default: `backup`). Configuration is read from a `.env` file placed
alongside this script.

---

## Prerequisites

- [BorgBackup](https://www.borgbackup.org/) installed.
- Bash 4.0 or later
- A dedicated system user to run backups (default: `backup`)
- Write access to the intended backup destination and log storage paths

> [!warning]
> backup user needs sudo access to `borg` command without password prompt and envirioment inheritance, best done through visudo.
> 
> Example: `backup ALL=(ALL) NOPASSWD: SETENV: /usr/bin/borg`

---

## Configuration

All variables are set in a `.env` file placed in the same directory as
`entrypoint.sh`. Values defined there take precedence over the built-in defaults.

| Variable | Default | Description |
|---|---|---|
| `BACKUP_USER` | `backup` | User that must invoke the script |
| `BACKUP_DESTINATION` | `/mnt/backup/data` | Root path of the Borg repository |
| `BACKUP_LOG_STORAGE` | `/mnt/backup/log` | Directory for backup logs |
| `BACKUP_PASSWORD` | *(see note)* | Passphrase for repository encryption — **always override** |
| `BACKUP_ITEMS` | `/home` | Colon-separated list of paths to archive |

### `BACKUP_PASSWORD`

The script ships with a placeholder default. **Always override it** before use —
leaving the default in place means anyone who reads the script can decrypt the
repository.

### `BACKUP_ITEMS`

Paths are separated by `;`, the same convention as `$PATH`. Spaces inside
directory names are handled correctly:

```sh
BACKUP_ITEMS='/home;/var/spaced dir;/etc'
```

> **Warning;** any path whose name contains a `;` character will be split at
> that point and treated as two separate entries, producing an incorrect backup.
> Avoid paths with `;` in their name, or rename them before use.

If `BACKUP_ITEMS` is unset the script falls back to `/home`.

### `.env` example

```sh
BACKUP_USER='backup'
BACKUP_DESTINATION='/mnt/backup/data'
BACKUP_LOG_STORAGE='/mnt/backup/log'
BACKUP_PASSWORD='your-strong-passphrase-here'
BACKUP_ITEMS='/home:/etc:/var/lib/postgresql'
```

---

## Usage

```sh
sudo -u backup ./my-silly-borg/entrypoint.sh
```

The script must be run as the user defined in `BACKUP_USER`. If invoked as any
other user it will exit immediately with `[ FATAL ]`.

---

## Directory structure

```
my-silly-borg/
├── entrypoint.sh       # this script
├── .env                # local configuration overrides (not committed)
└── ...
```

At runtime the script expects (or will attempt to create):

```
/mnt/backup/
├── data/               # Borg repository root  (BACKUP_DESTINATION)
└── log/                # backup logs           (BACKUP_LOG_STORAGE)
```

If either directory is absent, the script walks up the directory tree to verify
write access before attempting to create them with `mkdir -p`. It exits with
`[ FATAL ]` if neither the target nor any writable ancestor can be found.

---

## Encryption

The repository is initialized with `repokey` encryption. The key is stored
inside the repository itself, protected by `BACKUP_PASSWORD`. This means:

- The repository is unreadable without the passphrase.
- **Back up the key** with `borg key export` after the first run — if the
  repository is lost, the key inside it is also lost.
- `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK` is exported to suppress Borg's
  interactive prompt when it cannot find an encryption marker on an existing repo.

---

## Output levels

| Flag | Meaning |
|---|---|
| `[ INFO ]` | Normal operation — no action required |
| `[ WARN ]` | Recoverable condition — the script will attempt to continue |
| `[ FATAL ]` | Unrecoverable error — always followed by `[ EXIT ]` and a non-zero exit |
