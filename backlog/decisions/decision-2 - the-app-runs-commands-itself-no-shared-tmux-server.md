---
id: decision-2
title: The app runs commands itself; no shared tmux server
date: 2026-10-15
status: accepted
origin: evidence
tasks: []
---

## Context

The spike showed a tmux server started by the app inherits its grant. Any process running as the user can connect to a tmux socket.

## Options Considered

1) tmux server owned by the app. 2) App runs each approved command as a child, keyed per session.

## Decision

Option 2: a tmux socket would skip approval and the trace.

## Evidence

- `Sources/AgentsMissionControl/Privileged.swift`

## Consequences

No interactive privileged shell for the person yet.
