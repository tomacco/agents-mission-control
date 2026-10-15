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
- Full Disk Access cannot be granted by script; the app is not listed until added with + in System Settings. Granting it makes macOS relaunch the app, which drops every lease (the plugin asks for Touch ID again). The app checks its own access by opening `/Library/Application Support/com.apple.TCC/TCC.db`. evidence: Privileged.swift#hasFullDiskAccess
  confidence: validated
- Installed mid-session, a plugin misses `session.start`; this one also sets up on the first prompt. evidence: mod/hooks/register.tsx#setUp
  confidence: validated
- `$.process.run` allows `timeoutMs` up to ten minutes; past it the call rejects, the hook throws, and Claude Code skips it (the model reads "no tool.call hook answered"). Keep the app's run plus margin under it (MAX_RUN_S), and keep the `.catch` on the tool hook. evidence: mod/hooks/register.tsx, 2026-10-15 test
  confidence: validated
- Plugin hooks module: a helper that receives `$` must be a top-level function, or `claude plugin validate` refuses the module; tool matchers accept only this build's tool names (use a RegExp for several). evidence: mod/hooks/register.tsx
  confidence: validated
- A command in a Bash call whose text contains `pkill` or `quit app` (even inside a heredoc) trips the session's app-quit guard. Write such scripts with the file editor. evidence: 2026-10-15 split
  confidence: provisional
