# Changelog

## 0.1.0 (2026-10-15)

First public release.

- Menu bar pill with three tiles: hands off (agents may not speak, play sounds or drive input), caffeinate, and projects serving on localhost.
- Hands-off enforcement in two layers: the `amcd` LaunchAgent and a Claude Code `PreToolUse` hook.
- Privileged sessions: the app holds Full Disk Access and runs commands that a person approved for a Claude Code session, with a hash-chained trace log.
- The `amc` Claude Code plugin: the `privileged_bash` tool, the approval question and a side pane.
- Tests: `tests/test-hands-off.sh` (18 checks) and `tests/test-privileged.sh` (13 checks).
