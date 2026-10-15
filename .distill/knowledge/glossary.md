---
domain: glossary
scope: terms used in code, docs and UI
last_validated: 2026-10-15
staleness_threshold: 180
---

# Glossary

- **Privileged session**: a Claude Code session whose approved commands run inside the app with its Full Disk Access. evidence: README.md
- **Lease**: an approval for a session, scope `once` or `session`. evidence: Privileged.swift#Lease
- **Approval**: Touch ID or the login password, asked by the app before a lease opens. evidence: Privileged.swift#personApproves
- **Trace**: `~/.amc/trace.jsonl`, the hash-chained log of every request. evidence: Privileged.swift#trace
- **Channel**: a named install (`AMC_CHANNEL`); `test` is a separate copy with its own identity and grant. evidence: channel.sh
- **Mod**: Claude Code's name for a plugin built from a hooks module; here `mod/`, plugin name `amc`. evidence: mod/.claude-plugin/plugin.json
  confidence: validated
