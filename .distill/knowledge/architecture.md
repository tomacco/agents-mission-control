---
domain: architecture
scope: components, entrypoints, state locations, trust boundaries
last_validated: 2026-10-15
staleness_threshold: 90
---

# Architecture

## Components
- **App** (SwiftPM executable `AgentsMissionControl`, bundle `co.tomac.amc`, accessory app: no menu bar item, no window). `main.swift` starts `Privileged` and handles the grant step. evidence: Package.swift, Sources/AgentsMissionControl/main.swift
  confidence: validated
  origin: directive
- **Privileged.swift**: Unix socket server, peer check, Touch ID approval, leases, runs, trace. evidence: Sources/AgentsMissionControl/Privileged.swift
- **Claude Code plugin** `mod/` (name `amc`): tool `privileged_bash`, side pane, status lines, embedded socket client; marketplace file `.claude-plugin/marketplace.json`. evidence: mod/
- **Installer**: `install.sh` hands a terminal to `tools/installer.py` (animated steps, signature card, guided Full Disk Access); `uninstall.sh`; `channel.sh` names an install (`AMC_CHANNEL=test` is a separate copy). evidence: install.sh, tools/installer.py, channel.sh
- **LaunchAgent** `launchd/co.tomac.amc.app.plist` (templated) opens the app at login. evidence: install.sh
  confidence: validated

## Data flow
- Plugin or `bin/amc-call` → `~/.amc/amc.sock` → app. Ops: open, run, end, status, grant (one JSON line each way).
- Trust: caller must descend from Anthropic-signed Claude Code (dynamic code-signature check on the live pid); a lease belongs to that claude pid and opens only after Touch ID or the login password; scopes `once` and `session`.
- Commands run as the app's children (`/bin/zsh -o pipefail -c`), inheriting its Full Disk Access; output to `~/.amc/runs/<id>.log`; every request hash-chained into `~/.amc/trace.jsonl`.
  evidence: Privileged.swift, mod/hooks/register.tsx, tests/test-privileged.sh
  confidence: validated

## State on disk
- `~/.amc/` (0700): `amc.sock`, `trace.jsonl`, `runs/`; the folder comes from Info.plist `AMCHome` (per channel). evidence: build.sh, channel.sh
  confidence: validated

## Related
- Agent Board (tomacco/agent-board) owns hands off; this repo only reads its flag `~/.agent-board/hands-off` before playing a sound. evidence: tools/installer.py#hands_off
  confidence: validated
