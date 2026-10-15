---
domain: glossary
scope: terms used in code, docs and UI
last_validated: 2026-10-15
staleness_threshold: 180
---

# Glossary

- **Hands off**: switch that forbids agents to speak, play sounds or drive mouse and keyboard; the file `~/.amc/hands-off`. evidence: README.md
- **Clawd**: the pixel mascot in the pill and in the plugin pane. evidence: Bar.swift#Art
- **Pill**: the single menu bar status item (Clawd, cup, rack). evidence: README.md
- **amcd**: the enforcer LaunchAgent that kills blocked processes while hands off is on. evidence: bin/amcd
- **Privileged session**: a Claude Code session whose approved commands run inside the app with its Full Disk Access. evidence: README.md
- **Lease**: an approval for a session, scope `once` or `session`. evidence: Privileged.swift#Lease
- **Key**: the secret the app gives the first caller in a claude process; every later op must carry it. evidence: Privileged.swift#register
- **Trace**: `~/.amc/trace.jsonl`, the hash-chained log of every request. evidence: Privileged.swift#trace
- **Mod**: Claude Code's name for a plugin built from a hooks module; here `mod/`, plugin name `amc`. evidence: mod/.claude-plugin/plugin.json
  confidence: validated
