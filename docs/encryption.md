# Encryption

Your backup is locked with `repokey` encryption. The key that unlocks it is
stored inside the backup repository itself, and is protected by
`BACKUP_PASSWORD`.

What this means for you:

- Without the password, nobody can read your backup — **including you.**
- **Save a copy of the key somewhere safe.** Run `borg key export` after your
  first backup, and store the result somewhere other than the backup itself.
  If you lose the repository, you lose the key too.

## Two safety switches the script sets automatically

- `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK` — stops Borg from asking you to
  confirm access to a repository it doesn't recognize as encrypted.
- `BORG_CHECK_I_KNOW_WHAT_I_AM_DOING=NO` — this script never runs the risky
  `borg check --repair` command. But if it (or a future version) ever did,
  this setting makes sure Borg's "this could cause data loss" warning is
  answered with **no** by default, instead of silently proceeding.

[← Back to README](../README.md)
