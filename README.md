# my-silly-borg

A script that backs up your files using [BorgBackup](https://www.borgbackup.org/),
then automatically deletes old backups you don't need anymore.

## What you need first

- BorgBackup (the script installs it for you if it's missing)
- Bash 4.0 or newer
- A user account just for running backups (default name: `backup`)
- That user needs permission to run `borg` with `sudo`, without typing a
  password. Add a line like this with `sudo visudo`:

  ```
  backup ALL=(ALL) NOPASSWD: SETENV: /usr/bin/borg
  ```

## Set it up

1. Put `entrypoint.sh` and a `.env` file in the same folder.
2. In `.env`, at minimum, set your own `BACKUP_PASSWORD` and the folders you
   want backed up (`BACKUP_ITEMS`). See [Configuration](docs/configuration.md)
   for every setting.
3. Lock down the `.env` file so only its owner can read it:

   ```sh
   chmod 600 .env
   ```

## Run it

```sh
sudo -u backup ./entrypoint.sh
```

That's it — the script backs up your files, deletes old backups you no
longer need, and cleans up its own logs. See [Usage](docs/usage.md) for the
quiet/cron-friendly mode.

## Want more detail?

- [Configuration](docs/configuration.md) — every setting you can put in `.env`
- [Usage](docs/usage.md) — how to run it, normal vs. quiet mode
- [How it works](docs/how-it-works.md) — what the script actually does, step by step
- [Directory structure](docs/directory-structure.md) — where files end up
- [Encryption](docs/encryption.md) — how your backup is locked, and what to back up yourself
- [Exit codes & log messages](docs/exit-codes.md) — what `[ WARN ]`, `[ FATAL ]`, etc. mean
