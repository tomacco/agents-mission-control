---
domain: gotchas
scope: traps that cost time in this repo
last_validated: 2026-10-15
staleness_threshold: 90
---

# Gotchas

- [IMPORTANT] Never click the menu bar or post synthetic input to test the UI: a person may be at the keyboard. Use `--preview`. evidence: AGENTS.md
  confidence: validated
  origin: directive
- [IMPORTANT] If `bin/amcctl status` says hands off is on, do not speak, play sounds or drive input, and never turn it off yourself. evidence: AGENTS.md, hooks/hands-off-guard.sh
  confidence: hardened
  origin: directive
- Running the tests with `bash` fails (`A: unbound variable`): they are zsh. evidence: tests/*.sh shebang
  confidence: validated
- An ad-hoc signed build gets a new code identity each build, so macOS drops its Full Disk Access grant. Keep Developer ID signing. evidence: build.sh comment
  confidence: validated
- Full Disk Access cannot be granted by script; the app is not listed until added with + in System Settings. Granting it makes macOS relaunch the app, so the socket is gone for a second or two. evidence: 2026-10-15 install
  confidence: provisional
- The privileged session key binds to the first caller in a claude process. `tests/test-privileged.sh` takes it, so the plugin then fails in that same session; and in a session where the plugin loaded first, the test skips the key checks. evidence: Privileged.swift#register, tests/test-privileged.sh
  confidence: validated
- Plugin hooks module: a helper that receives `$` must be a top-level function, or `claude plugin validate` refuses the module; tool matchers only accept this build's tool names (use a RegExp for several). evidence: mod/hooks/register.tsx
  confidence: validated
- Changing the bundle id makes a new TCC identity: re-grant permissions and `tccutil reset <service> <old id>` before deleting the old app. evidence: rename commit 593896a
  confidence: validated
