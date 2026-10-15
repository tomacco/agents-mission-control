---
id: decision-1
title: Grant Full Disk Access per session, run commands inside the app
date: 2026-10-15
status: accepted
origin: evidence
tasks: []
---

## Context

Agents need Full Disk Access for some paths; giving it to Terminal gives it to every process forever. A per-request read proxy was considered first.

## Options Considered

1) Terminal with Full Disk Access. 2) Per-request proxy that hands bytes or copies to the agent. 3) Per-session approval, commands run as the app's children.

## Decision

Option 3. A per-request proxy had to rebuild every tool's file access (sqlite side files, directory trees, following files, writes, built-in Read), and its edge cases grew with each use case. A session lease keeps all Unix tools working; the trace records every command.

## Evidence

- `tests/test-privileged.sh`
- `Sources/AgentsMissionControl/Privileged.swift`

## Consequences

Inside an open session the agent can read everything the app can. Evidence is per command, not per byte.
