# Usage

Run the script as the backup user:

```sh
sudo -u backup ./my-silly-borg/entrypoint.sh
```

If you run it as any other user, it stops immediately with a `[ FATAL ]`
message.

## Normal mode vs. quiet mode

| Command | What happens |
|---|---|
| `./entrypoint.sh` | Shows output on screen **and** saves it to a log file |
| `./entrypoint.sh --quiet` or `./entrypoint.sh -q` | Saves output to a log file only — nothing shown on screen |

Quiet mode is meant for cron jobs, where nobody is watching the screen
anyway.

[← Back to README](../README.md)
