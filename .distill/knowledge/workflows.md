---
domain: workflows
scope: build, install, test, plugin checks, release
last_validated: 2026-10-31
staleness_threshold: 60
---

# Workflows

## Build and install
- `./build.sh` → `build/AgentsMissionControl.app`, signed with the first Developer ID identity (hardened runtime, `AgentsMissionControl.entitlements`), ad hoc otherwise. evidence: build.sh
  confidence: validated
- `./install.sh` (idempotent; animated in a terminal, plain with `AMC_PLAIN=1`; `AMC_NO_GRANT=1` skips the Full Disk Access step). evidence: install.sh
  confidence: validated
- install.sh restarts the app: launchd runs the binary (KeepAlive), and reloading the job restarts it. An instance started outside launchd (by 0.2.0 and earlier, or by macOS) keeps the socket until it quits; launchd's copy waits for it. evidence: launchd/co.tomac.amc.app.plist, main.swift
  confidence: validated
- A separate test copy: `AMC_CHANNEL=test ./install.sh` and `AMC_CHANNEL=test ./uninstall.sh --yes`. evidence: channel.sh
  confidence: validated

## Test
- `zsh tests/test-privileged.sh` (needs no person) and `--touch-id` (two Touch ID prompts), from a Claude Code session. evidence: tests/test-privileged.sh
  confidence: validated
- `zsh tests/test-keepalive.sh` (the app comes back after it quits; a second copy steps aside). `zsh tests/test-grant-order.sh` (opens real windows with a test copy). `zsh tests/try-install.sh` (whole install as a new user, then removed). evidence: tests/
  confidence: validated

## Plugin
- `claude plugin test mod` (pane drawing, relative times, order), `claude plugin validate mod` and `claude plugin validate .`; run a session with it: `claude --plugin-dir mod`. evidence: mod/
  confidence: validated

## Release
- Set `VERSION` (app version; the plugin keeps its own in mod/.claude-plugin/plugin.json), add a `## X.Y.Z (date)` CHANGELOG.md section, merge to main, then `zsh scripts/release.sh` on the author's Mac: builds, notarizes and staples, verifies with `scripts/verify-app.sh`, tags `vX.Y.Z` and uploads `AgentsMissionControl.zip`. `--dry-run` stops before the tag. evidence: scripts/release.sh, backlog decision-5
  confidence: provisional
- `install.sh` installs `releases/latest/download/AgentsMissionControl.zip` and refuses it unless the verifier passes; running it again is the update. A test channel or `--from-source` builds instead. evidence: install.sh, tests/test-install.sh
  confidence: provisional

## Knowledge freshness
- `bash scripts/check-freshness.sh` (pre-commit and CI); after editing `.distill/`, run `bash scripts/render-adapters.sh`. evidence: scripts/
  confidence: hardened
