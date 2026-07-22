# Directory structure

Where the script itself lives:

```
my-silly-borg/
├── entrypoint.sh       # the script
├── .env                # your settings (don't commit this to git)
└── ...
```

Where the script puts things, based on the example `.env` in
[Configuration](configuration.md):

```
/mnt/backup/
├── data/               # the backup repository   (BACKUP_DESTINATION)
└── log/                # backup logs              (BACKUP_LOG_DESTINATION)
```

If you don't set those, they default to `/mnt/my-silly-borg` and
`<folder containing entrypoint.sh>/logs`.

If either folder doesn't exist yet, the script checks that it (or a parent
folder above it) is writable, then creates it. If nothing writable can be
found anywhere up the folder tree, the script stops with `[ FATAL ]`.

[← Back to README](../README.md)
