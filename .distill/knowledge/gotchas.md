---
domain: gotchas
scope: traps that cost time in this repo
last_validated: 2026-10-15
staleness_threshold: 90
---

# Gotchas

- [IMPORTANT] Never let approval live only in the plugin: agents reach `~/.amc/amc.sock` directly (seen in a 2026-10-15 test, the agent opened its own lease). Approval is Touch ID in the app. evidence: Privileged.swift#personApproves, backlog decision-3
  confidence: validated
- [IMPORTANT] No menu bar item: some companies block running unknown apps but not a Claude Code plugin, so the UI lives in the plugin and installer. evidence: AGENTS.md
  confidence: validated
  origin: directive
- Running the tests with `bash` fails: they are zsh. evidence: tests/*.sh shebang
  confidence: validated
- An ad-hoc signed build gets a new code identity each build, so macOS drops its Full Disk Access grant. Keep Developer ID signing. evidence: build.sh
  confidence: validated
- Full Disk Access cannot be granted by script; the app is not listed until added with + in System Settings. Granting it makes macOS quit the app (Quit & Reopen), which drops every lease; launchd brings it back (KeepAlive), and the plugin asks for Touch ID again. Only the job labelled `<bundle id>.app` may wait for the socket: macOS-started copies (`application.<bundle id>.*`) exit. The app checks its own access by opening `/Library/Application Support/com.apple.TCC/TCC.db`. evidence: Privileged.swift#hasFullDiskAccess
  confidence: validated
- Installed mid-session, a plugin misses `session.start`; this one also sets up on the first prompt. evidence: mod/hooks/register.tsx#setUp
  confidence: validated
- `$.process.run` allows `timeoutMs` up to ten minutes; past it the call rejects, the hook throws, and Claude Code skips it (the model reads "no tool.call hook answered"). Keep the app's run plus margin under it (MAX_RUN_S), and keep the `.catch` on the tool hook. evidence: mod/hooks/register.tsx, 2026-10-15 test
  confidence: validated
- A render hook reads the pane's size and seat from `e.props` (`bodyColumns`, `placement`), not `e`. Any invalid prop (an empty color) makes the engine refuse the whole tree and draw its own: test with `claude plugin test mod`. The pane docks beside the transcript only in fullscreen (`"tui": "fullscreen"`); otherwise it sits above the prompt. evidence: mod/tests/pane.test.tsx
  confidence: validated
- Plugin hooks module: a helper that receives `$` must be a top-level function, or `claude plugin validate` refuses the module; tool matchers accept only this build's tool names (use a RegExp for several). evidence: mod/hooks/register.tsx
  confidence: validated
- A command in a Bash call whose text contains `pkill` or `quit app` (even inside a heredoc) trips the session's app-quit guard. Write such scripts with the file editor. evidence: 2026-10-15 split
  confidence: provisional
- `osascript -e 'tell application "X" to get name'` sends no Apple event when X is not running (AppleScript answers name, id and version itself), so it proves nothing about Automation. Use a real command, for example `count workbooks` for Excel. evidence: backlog task-6
  confidence: validated
- macOS 27.2 here has no per-user TCC.db at `~/Library/Application Support/com.apple.TCC/`, not even for a process with Full Disk Access (the system one has no AppleEvents rows). Read Automation with `tccutil list -s AppleEvents [-b <bundle id>]` (exit 0 granted, 1 denied); it does not name the target app. A build without `NSAppleEventsUsageDescription` and without hardened runtime still gets the prompt (no -1743). A stored "Don't Allow" for AMC itself does give -1743 with no prompt; `tccutil reset AppleEvents co.tomac.amc` clears it (2026-11-01). evidence: backlog task-6
  confidence: validated
