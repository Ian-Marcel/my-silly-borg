# How it works

Every time you run the script, it does four things, in order.

## 1. Create a backup

The script runs `borg create` to pack up your files (`BACKUP_ITEMS`) into a
new backup, named after your computer and the current time — like
`myhost_2026-07-22T09:00:00`.

A few details, in case you're curious:

- Files are compressed using whatever you set in `BACKUP_COMPRESSION_METHOD`
  (`zstd` by default). See [Configuration](configuration.md) for the other
  options.
- Any folder containing a `CACHEDIR.TAG` marker file is skipped automatically
  — this is a standard way build tools mark "this is just cache, don't back
  it up."
- The log only lists files that were **A**dded, **M**odified, or had an
  **E**rror — unchanged files aren't listed, to keep logs short.
- A summary (size, space saved, etc.) is printed at the end.

If `borg` (the backup program) isn't installed, the script tries to install it
for you automatically.

## 2. Prune old backups

The script runs `borg prune` to delete backups you no longer need, based on
your `KEEP_HOURLY` / `KEEP_DAILY` / `KEEP_WEEKLY` / `KEEP_MONTHLY` settings.

Only backups made by *this* computer are considered — if you're storing
backups from several computers in one place, the others are left alone.

## 3. Compact the repository

The script runs `borg compact`. Deleting old backups in step 2 doesn't
actually free up disk space by itself — this step does that.

## 4. Clean up old log files

Finally, the script checks which backups still exist, and deletes any log
file whose matching backup has been pruned. This keeps your log folder from
growing forever.

[← Back to README](../README.md)
