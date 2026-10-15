# Changelog

## Unreleased

- Plugin 0.2.8: while Touch ID is up the pane shows a breathing thinking orb, drawn in Braille from the thinking-orbs engine by Jakub Antalik (MIT, vendored in `mod/vendor/thinking-orbs`).
- Touch ID text is a short phrase: "let <agent> read ~/Library/Messages for this session"; the full reason and paths are in the pane.
- Plugin 0.2.6: while Touch ID is up the pane shows a fingerprint with a scan line, a TOUCH ID badge, the reason and the paths. A new palette (softer session accents, fixed state colors). A session without a usable agent name (no PortCall, or a generic "claude-code") gets a stable two-word name; the subtitle defaults to the project folder; both fields are optional.
- Plugin 0.2.5: a redesigned pane. The lock and the agent in the session's color, an ACCESS OPEN / NO ACCESS badge, the reason and paths under small-caps labels, recent runs as cards with a colored border by result, a spinner while a command runs, and output under a gutter.
- Plugin 0.2.4: `/amc` shows the pane on demand with the session's access and the app's state. The "no Full Disk Access" hint now needs a failed call (an error, or a command's stderr); a successful search whose output contains the words no longer triggers it.
- The app stays up: launchd runs its binary with KeepAlive, so it comes back seconds after macOS quits it (switching on Full Disk Access does) or it crashes; a copy macOS reopens on its own steps aside. `install.sh` now restarts the app. Plugin 0.2.3 starts the app itself when it finds it not running. Proof: `tests/test-keepalive.sh`.
- Installer: a big pulsing YOUR TURN banner (with a chime) before the Full Disk Access step, and a big ALL SET! that wipes in under falling confetti once access is on.
- Plugin 0.2.2: the pane shows a lock (open while access is granted, in a color per session) in place of Clawd, the newest run on top with a relative time ("a minute ago"), and closes 90 s after the last run. Above the prompt it says how to get the side panel (fullscreen in /config). Fixed: an unset color made Claude Code refuse the whole pane, and the pane read its width and placement from the wrong place. Plugin tests: `claude plugin test mod`.
- `tests/try-install.sh` copies your Claude Code layout setting into its throwaway config.
- Plugin 0.2.1: a `timeout_seconds` of 600 made the app call exceed Claude Code's ten-minute process limit, the hook threw and the agent read "no tool.call hook answered". Runs are capped at 585 s, failures inside the hook come back as a clear refusal, and the pane no longer sticks on a run that failed.
- The installer offers to install the Claude Code plugin itself (one Y), since a manual `/plugin install` step was skipped in testing. `tests/try-install.sh` installs it into its throwaway config and puts the test prompt on the clipboard.

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
