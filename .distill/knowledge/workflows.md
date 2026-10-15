---
domain: workflows
scope: build, install, test, preview, plugin checks, release
last_validated: 2026-10-15
staleness_threshold: 60
---

# Workflows

## Build
- `./build.sh` → `build/AgentsMissionControl.app`, signed with the first "Developer ID Application" identity, ad hoc otherwise. evidence: build.sh
  confidence: validated

## Install
- `./install.sh` (idempotent): build, copy to `~/Applications`, (re)load both LaunchAgents, register the hands-off hook in `~/.claude/settings.json`. evidence: install.sh
  confidence: validated
- [IMPORTANT] It does not restart a running app: quit it and `open -a ~/Applications/AgentsMissionControl.app`. evidence: install.sh (open -a on a running app is a no-op)
  confidence: validated

## Test
- `zsh tests/test-hands-off.sh` (18 checks, private flag, safe anytime). evidence: tests/test-hands-off.sh
  confidence: validated
- `zsh tests/test-privileged.sh` (15 checks, needs the installed app with Full Disk Access; run from a Claude Code session without the plugin: `! zsh tests/test-privileged.sh`). evidence: tests/test-privileged.sh
  confidence: validated

## Preview UI
- `build/AgentsMissionControl.app/Contents/MacOS/AgentsMissionControl --preview` prints a window number for `screencapture -o -l <n>`; it skips the socket server. evidence: Bar.swift, MissionControlApp.swift
  confidence: validated

## Plugin
- `claude plugin validate mod` and `claude plugin validate .` (marketplace); run a session with it: `claude --plugin-dir mod`. evidence: mod/, .claude-plugin/marketplace.json
  confidence: validated
- Install for users: `/plugin install amc --marketplace tomacco/agents-mission-control`. evidence: README.md
  confidence: provisional

## Release
- Bump `CFBundleShortVersionString` in build.sh and `version` in mod/.claude-plugin/plugin.json, add a CHANGELOG.md entry, tag `vX.Y.Z`, GitHub release. evidence: CHANGELOG.md, v0.1.0
  confidence: provisional
  origin: convention

## Knowledge freshness
- `bash scripts/check-freshness.sh` (pre-commit and CI); after editing `.distill/`, recompile with `bash scripts/render-adapters.sh`. evidence: scripts/
  confidence: hardened
