# my-silly-borg

A stupid bash script that simplify [BorgBackup](https://www.borgbackup.org/) for you.

## Project scope

### This project will:

- Automate the process of creating and managing backups,
  deleting old one according to retention policy that you can set.
- Provide an easy way to configure you backups, details in
  [Configuration](docs/configuration.md).

### This project will NOT:

- Handle restorations, head to BorgBackup
  [official documentaion](https://borgbackup.readthedocs.io/en/stable/quickstart.html#restoring-a-backup)
  for that.
- Handle remote backups, this is trickier, so let me break this down real quick:
  1. NO BorgBackup [server repository](https://borgbackup.readthedocs.io/en/stable/usage/serve.html#borg-serve),
    creation and management.
      > Maybe in future releases but very unlikely for now.
  2. NO [remote BACKUPS](https://borgbackup.readthedocs.io/en/stable/quickstart.html#remote-repositories),
    this script is LOCAL first, which kinda sucks
    because it'll be eating the same storage as the
    items being saved, but you can use an external
    HD/SSD to mitigate this limitation.
      > I plan to add remote backups as it's a much more useful
        than a server repository.

## Prerequisites

- BorgBackup (the script installs it for you if it's missing)
- Bash 4.0 or newer
- [OPTIONAL] A user account just for running backups (default is: `backup`)
- That user needs permission to run `borg` with `sudo`, without typing a
  password. Add a line like this with `sudo visudo`:

  ```
  backup ALL=(ALL) NOPASSWD: SETENV: /usr/bin/borg
  ```
> [!warning]
> Not complying with these prerequisites could(and probably will)
> result in issues/failures when running the script.

## Quickstart

1. [OPTIONAL] Create a specialized user for handling the backups as described in [Prerequisites](#prerequisites)..
2. Grant this user the rights to use borg with sudo without password prompt as described in [Prerequisites](#prerequisites).
3. Download this project repository with `git clone`.
4. Add configuration file (`.env` or `user-settings.conf`) in the project folder.
5. In this file, at minimum, set your own `BACKUP_PASSWORD` and the folders you
   want backed up (`BACKUP_ITEMS`). See [Configuration](docs/configuration.md)
   for every setting.
6. Lock down the you're settings file so only its owner can read it:

   ```sh
   chmod 600 .env # or user-settings.conf
   ```
7. Run it as the backup user:
  ```sh
  sudo -u <user> ./entrypoint.sh
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
