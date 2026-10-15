---
domain: workflows
scope: build, install, test, plugin checks, release
last_validated: 2026-10-15
staleness_threshold: 60
---

# Workflows

## Build and install
- `./build.sh` → `build/AgentsMissionControl.app`, signed with the first Developer ID identity, ad hoc otherwise. evidence: build.sh
  confidence: validated
- `./install.sh` (idempotent; animated in a terminal, plain with `AMC_PLAIN=1`; `AMC_NO_GRANT=1` skips the Full Disk Access step). evidence: install.sh
  confidence: validated
- [IMPORTANT] install.sh does not restart a running app: quit it, then `open -a ~/Applications/AgentsMissionControl.app`. evidence: install.sh
  confidence: validated
- A separate test copy: `AMC_CHANNEL=test ./install.sh` and `AMC_CHANNEL=test ./uninstall.sh --yes`. evidence: channel.sh
  confidence: validated

## Test
- `zsh tests/test-privileged.sh` (needs no person) and `--touch-id` (two Touch ID prompts), from a Claude Code session. evidence: tests/test-privileged.sh
  confidence: validated
- `zsh tests/test-grant-order.sh` (opens real windows with a test copy). `zsh tests/try-install.sh` (whole install as a new user, then removed). evidence: tests/
  confidence: validated

## Plugin
- `claude plugin validate mod` and `claude plugin validate .`; run a session with it: `claude --plugin-dir mod`. evidence: mod/
  confidence: validated

## Release
- Bump `CFBundleShortVersionString` in build.sh and `version` in mod/.claude-plugin/plugin.json, add a CHANGELOG.md entry, tag `vX.Y.Z`, GitHub release. evidence: CHANGELOG.md
  confidence: provisional
  origin: convention

## Knowledge freshness
- `bash scripts/check-freshness.sh` (pre-commit and CI); after editing `.distill/`, run `bash scripts/render-adapters.sh`. evidence: scripts/
  confidence: hardened
