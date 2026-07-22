# Exit codes & log messages

## Log message prefixes

Every line the script prints starts with one of these:

| Prefix | Meaning |
|---|---|
| `[ INFO ]` | Everything's fine, just letting you know what's happening |
| `[ WARN ]` | Something's a little off, but the script kept going |
| `[ FATAL ]` | Something's broken — the script stopped |

## Exit codes

Borg (the backup program) uses these codes: `0` = all good, `1` = finished
with a warning, `2` or higher = something failed.

The script runs three Borg commands (create, prune, compact) and reports the
worst of the three as its own final result:

| Exit code | Meaning |
|---|---|
| `0` | Everything finished successfully |
| `1` | Everything finished, but check the log — there was a warning |
| `2` or higher | Something failed — check the log |

[← Back to README](../README.md)
