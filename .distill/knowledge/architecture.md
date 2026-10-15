---
domain: architecture
scope: components, entrypoints, state locations, trust boundaries
last_validated: 2026-10-15
staleness_threshold: 90
---

# Architecture

## Components
- **Menu bar app** (SwiftPM executable `AgentsMissionControl`, bundle `co.tomac.amc`, LSUIElement). evidence: Package.swift, build.sh
  - `MissionControlApp.swift`: entry, the `MissionControl` observable model (polls flag, caffeinate, servers). evidence: Sources/AgentsMissionControl/MissionControlApp.swift
  - `Bar.swift`: the one NSStatusItem pill and pixel art; `Panel.swift`: the glass panel tiles. evidence: Sources/
  - `Privileged.swift`: Unix socket server for privileged sessions. evidence: Sources/AgentsMissionControl/Privileged.swift
- **Scripts** in `bin/`: `amcctl` (flip hands off), `amcd` (enforcer loop), `servers` (localhost listeners as TSV), `amc-call` (socket client). evidence: bin/
- **Claude Code hook** `hooks/hands-off-guard.sh` (PreToolUse on Bash). evidence: install.sh
- **Claude Code plugin** `mod/` (name `amc`): hooks module `mod/hooks/register.tsx`, state contract `mod/types/index.d.ts`; marketplace file at `.claude-plugin/marketplace.json`. evidence: mod/, .claude-plugin/
- **LaunchAgents** `launchd/*.plist`, templated with `@ROOT@`/`@HOME@` by install.sh. evidence: install.sh
- `swiftbar/`: the retired SwiftBar plugins; the caffeinate tile still calls `swiftbar/caffeinate/caffeinate.5s.sh`. evidence: MissionControlApp.swift#caffeinate
  confidence: validated

## Data flow: hands off
- The panel and `amcctl` only write or remove `~/.amc/hands-off`; `amcd` and the hook enforce. [IMPORTANT] Keep enforcement out of the UI.
  evidence: README.md, AGENTS.md
  confidence: validated
  origin: directive

## Data flow: privileged sessions
- Plugin → `bin/amc-call` → `~/.amc/amc.sock` → app. Ops: register, open, run, end, status (one JSON line each way).
- Trust: caller must descend from Anthropic-signed Claude Code (dynamic code-signature check on the live pid); key bound to the claude pid; leases `once` or `session`.
- Commands run as the app's children (`/bin/zsh -c`), so they inherit the app's Full Disk Access; output to `~/.amc/runs/<id>.log`; every request hash-chained into `~/.amc/trace.jsonl`.
  evidence: Privileged.swift, mod/hooks/register.tsx, tests/test-privileged.sh
  confidence: validated

## State on disk
- `~/.amc/` (0700): `hands-off`, `amc.sock`, `trace.jsonl`, `runs/`. The key `AMCRoot` in Info.plist points the app at the checkout (scripts run live from the repo). evidence: build.sh, MissionControlApp.swift
  confidence: validated
