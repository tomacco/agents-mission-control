---
id: decision-3
title: Touch ID in the app is the only approval
date: 2026-10-15
status: accepted
origin: evidence
tasks: []
---

## Context

A test agent, with the plugin installed mid-session, called the socket itself, took the session key and opened Full Disk Access without the person. Anything running as the user can reach the socket, and Terminal holds Accessibility, so a clicked dialog can be faked.

## Options Considered

1) Approval in the plugin plus a session key. 2) A dialog in the app. 3) Touch ID or login password in the app (LocalAuthentication).

## Decision

Option 3. An agent cannot pass Touch ID. Session keys are removed; the plugin's own question is removed.

## Evidence

- `Sources/AgentsMissionControl/Privileged.swift`
- `tests/test-privileged.sh`

## Consequences

One Touch ID per session. Machines without Touch ID ask for the login password.
