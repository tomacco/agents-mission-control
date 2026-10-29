---
id: decision-4
title: AMC owns Automation for agents, not momai
date: 2026-10-29
status: accepted
origin: directive
tasks: [task-6]
---

## Context

An agent that drives another app with osascript from Terminal charges the Automation grant to Terminal, and then every process in Terminal holds it. AMC already runs approved commands as children of its signed app, so TCC charges those to AMC (the same route that gives them Full Disk Access). momai (tomacco/momai) also replaces Terminal's TCC grants.

## Options Considered

1) AMC holds Automation grants, per approved session, with Touch ID and the trace. 2) momai holds them. 3) Leave them on Terminal.

## Decision

1. AMC owns Automation for agents' commands. Terminal keeps its existing System Events grant (momai docs/DECISIONS.md); no tccutil reset of Terminal's AppleEvents.

## Evidence

## Consequences

build.sh carries NSAppleEventsUsageDescription; the plugin routes -1743 to privileged_bash; hardened runtime (task-5) will need com.apple.security.automation.apple-events.
