# Changelog

## 0.2.0 (2026-10-15)

Split: this repository is now only privileged sessions. The menu bar pill (hands off, caffeinate, localhost) moved to [Agent Board](https://github.com/tomacco/agent-board).

- The app has no menu bar item; the installer and the Claude Code plugin are what the person sees. `install.sh` removes the 0.1.0 enforcer and hook.
- Security: the app asks for Touch ID (or the login password) before it opens access for a session. In a test an agent reached the socket itself and opened access without the person; session keys are gone, Touch ID is the only approval.
- Commands run with `pipefail`.
- The plugin sets itself up on the first prompt when installed in the middle of a session.
- Animated installer in the terminal: steps with progress, the code signature shown with its signer, and Full Disk Access explained (with a short drawing of the two moves) before any window opens. N is accepted; the panel and Claude Code ask again later.
- `AMC_CHANNEL=test` installs a separate copy; `uninstall.sh` removes an install and its permissions; `tests/try-install.sh` tries the whole install and cleans up.
- Full Disk Access setup with the least friction macOS allows: `install.sh`, the panel and the plugin open the settings pane and show the app in Finder ready to drag in, then wait for the switch and carry on.
- The app checks its own Full Disk Access; the pill shows an amber dot and the panel a grant tile while it is missing; `run` refuses with a clear message.
- The plugin warns at session start when the app is missing or has no access, takes a new key after the app restarts, and reopens the session's approval.

## 0.1.0 (2026-10-15)

First public release.

- Menu bar pill with three tiles: hands off (agents may not speak, play sounds or drive input), caffeinate, and projects serving on localhost.
- Hands-off enforcement in two layers: the `amcd` LaunchAgent and a Claude Code `PreToolUse` hook.
- Privileged sessions: the app holds Full Disk Access and runs commands that a person approved for a Claude Code session, with a hash-chained trace log.
- The `amc` Claude Code plugin: the `privileged_bash` tool, the approval question and a side pane.
- Tests: `tests/test-hands-off.sh` (18 checks) and `tests/test-privileged.sh` (15 checks).
